# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/middleware"
require "protocol/http"
require "protocol/grpc/test_middleware"
require "protocol/grpc/test_message"

describe Protocol::GRPC::Middleware do
	let(:headers) do
		Protocol::HTTP::Headers.new([
			["content-type", "application/grpc+proto"]
		])
	end
	let(:body) {Protocol::HTTP::Body::Buffered.new}
	let(:request) do
		Protocol::HTTP::Request.new(
			"https",
			"localhost",
			"POST",
			"/my_service.Greeter/SayHello",
			nil,
			headers,
			body
		)
	end
	
	with "single service handler" do
		let(:service_handler) do
			handler_class = Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage
						}
					}
				end
				
				def say_hello(_input, output, _call)
					message = Protocol::GRPC::Fixtures::TestMessage.new(value: "Hello")
					output.write(message)
				end
			end
			handler_class.new
		end
		let(:handler) {TestMiddleware.new(service_handler: service_handler)}
		
		it "calls handler method" do
			# Write a request message
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			request_data = request_message.to_proto
			prefix = [0].pack("C") + [request_data.bytesize].pack("N")
			body.write(prefix + request_data)
			body.close
			
			response = handler.call(request)
			
			expect(response.status).to be == 200
			content_type = response.headers["content-type"]
			content_type = content_type.first if content_type.is_a?(Array)
			expect(content_type.to_s).to be == "application/grpc+proto"
			
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
		end
		
		it "returns UNIMPLEMENTED for unknown method" do
			# Create a handler with a service that doesn't have the method in rpc_descriptions
			handler_class = Class.new do
				def self.rpc_descriptions
					{} # Empty - no methods defined
				end
			end
			service_without_method = handler_class.new
			handler_without_method = TestMiddleware.new(service_handler: service_without_method)
			body.close
			
			response = handler_without_method.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::UNIMPLEMENTED
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /RPC descriptor not found/
		end
	end
	
	with "service multiplexing" do
		let(:services) {{}}
		let(:handler) {TestMiddleware.new(services: services)}
		
		it "returns UNIMPLEMENTED for unknown service" do
			response = handler.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::UNIMPLEMENTED
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /Service not found/
		end
		
		it "calls handler method for registered service" do
			handler_class = Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage
						}
					}
				end
				
				def say_hello(_input, output, _call)
					message = Protocol::GRPC::Fixtures::TestMessage.new(value: "Hello")
					output.write(message)
				end
			end
			service_handler = handler_class.new
			services["my_service.Greeter"] = service_handler
			
			# Write a request message
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			request_data = request_message.to_proto
			prefix = [0].pack("C") + [request_data.bytesize].pack("N")
			body.write(prefix + request_data)
			body.close
			
			response = handler.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
		end
	end
	
	with "rpc_descriptions" do
		let(:handler_class) do
			Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage,
							request_streaming: false,
							response_streaming: false
						}
					}
				end
				
				def say_hello(_input, output, _call)
					message = Protocol::GRPC::Fixtures::TestMessage.new(value: "Hello")
					output.write(message)
				end
			end
		end
		let(:service_handler) {handler_class.new}
		let(:handler) {TestMiddleware.new(service_handler: service_handler)}
		
		it "uses rpc_descriptions for type information" do
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			request_data = request_message.to_proto
			prefix = [0].pack("C") + [request_data.bytesize].pack("N")
			body.write(prefix + request_data)
			body.close
			
			response = handler.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
		end
	end
	
	with "error handling" do
		let(:service_handler) do
			handler_class = Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage
						}
					}
				end
				
				def say_hello(_input, _output, _call)
					raise "Test error"
				end
			end
			handler_class.new
		end
		let(:handler) {TestMiddleware.new(service_handler: service_handler)}
		
		it "handles standard errors" do
			body.close
			
			response = handler.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::INTERNAL
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /Test error/
		end
		
		it "handles gRPC errors" do
			handler_class = Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage
						}
					}
				end
				
				def say_hello(_input, _output, _call)
					raise Protocol::GRPC::NotFound, "Not found"
				end
			end
			grpc_error_handler = handler_class.new
			handler_with_error = TestMiddleware.new(service_handler: grpc_error_handler)
			body.close
			
			response = handler_with_error.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::NOT_FOUND
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /Not found/
		end
	end
end
