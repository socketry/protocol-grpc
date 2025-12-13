# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/middleware"
require "protocol/grpc/methods"
require "protocol/grpc/call"
require "protocol/grpc/body/readable_body"
require "protocol/grpc/body/writable_body"

# Test implementation of Middleware with service routing
class TestMiddleware < Protocol::GRPC::Middleware
	def initialize(app = nil, service_handler: nil, services: nil)
		super(app)
		@service_handler = service_handler
		@services = services
	end
	
	protected
	
	def dispatch(request)
		# Parse service and method from path
		service_name, method_name = Protocol::GRPC::Methods.parse_path(request.path)
		
		# Find service handler
		service_handler = if @services
			@services[service_name]
		else
			@service_handler
		end
		
		unless service_handler
			raise Protocol::GRPC::Error.new(Protocol::GRPC::Status::UNIMPLEMENTED, "Service not found: #{service_name}")
		end
		
		# Wrap service handler to handle method routing and rpc_descriptions
		wrapper = ServiceHandlerWrapper.new(service_handler, method_name)
		
		# Create protocol-level objects for gRPC handling
		encoding = request.headers["grpc-encoding"]
		input = Protocol::GRPC::Body::ReadableBody.new(request.body, encoding: encoding)
		output = Protocol::GRPC::Body::WritableBody.new(encoding: encoding)
		
		# Create call context
		response_headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
		response_headers["content-type"] = "application/grpc+proto"
		response_headers["grpc-encoding"] = encoding if encoding
		
		# Parse deadline from timeout header
		timeout_value = request.headers["grpc-timeout"]
		deadline = if timeout_value
			timeout_seconds = Protocol::GRPC::Methods.parse_timeout(timeout_value)
			require "async/deadline"
			Async::Deadline.start(timeout_seconds) if timeout_seconds
		end
		
		call = Protocol::GRPC::Call.new(request, deadline: deadline)
		
		# Delegate to service handler wrapper
		result = wrapper.call(input, output, call)
		
		# Handler may return a different output, or modify the existing one
		final_output = result.is_a?(Protocol::GRPC::Body::WritableBody) ? result : output
		final_output.close_write unless final_output.closed?
		
		# Mark trailers and add status
		response_headers.trailer!
		Protocol::GRPC::Metadata.add_status!(response_headers, status: Protocol::GRPC::Status::OK)
		
		Protocol::HTTP::Response[200, response_headers, final_output]
	end
	
	# Wrapper that handles method routing and type information
	class ServiceHandlerWrapper
		def initialize(service_handler, method_name)
			@service_handler = service_handler
			@method_name = method_name
			
			# Determine handler method and message classes from rpc_descriptions
			unless service_handler.class.respond_to?(:rpc_descriptions)
				raise Protocol::GRPC::Error.new(Protocol::GRPC::Status::UNIMPLEMENTED, "Service handler class must define rpc_descriptions")
			end
			
			rpc_descriptor = service_handler.class.rpc_descriptions[method_name]
			
			unless rpc_descriptor
				raise Protocol::GRPC::Error.new(Protocol::GRPC::Status::UNIMPLEMENTED, "RPC descriptor not found for method: #{method_name}")
			end
			
			@handler_method = rpc_descriptor[:method]
			@request_class = rpc_descriptor[:request_class]
			@response_class = rpc_descriptor[:response_class]
		end
		
		def call(input, output, call)
			# Recreate input/output with type information if available
			# We need to wrap the original input's underlying body with the correct message class
			if @request_class
				encoding = input.encoding
				underlying_body = input.body
				# Preserve any buffered data from the original input
				original_buffer = input.instance_variable_get(:@buffer)
				input = Protocol::GRPC::Body::ReadableBody.new(underlying_body, message_class: @request_class, encoding: encoding)
				# Copy buffered data if any exists
				if original_buffer && !original_buffer.empty?
					input.instance_variable_set(:@buffer, original_buffer.dup)
				end
			end
			
			if @response_class
				encoding = output.encoding
				# Create new output with type information
				# The original output's data is lost, but that's okay since we haven't written to it yet
				output = Protocol::GRPC::Body::WritableBody.new(message_class: @response_class, encoding: encoding)
			end
			
			# Call the actual handler method
			unless @service_handler.respond_to?(@handler_method)
				raise Protocol::GRPC::Error.new(Protocol::GRPC::Status::UNIMPLEMENTED, "Method not found: #{@method_name}")
			end
			
			@service_handler.send(@handler_method, input, output, call)
			
			# Return the output (which may have been replaced)
			output
		end
	end
end

