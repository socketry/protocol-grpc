# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/middleware"
require "protocol/http"

require "protocol/grpc/test_middleware"
require "protocol/grpc/test_message"

describe Protocol::GRPC::Middleware do
	let(:services) {{}}
	let(:middleware) {TestMiddleware.new(services: services)}
	
	with "#call" do
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
		
		it "passes non-gRPC requests to next middleware" do
			non_grpc_request = Protocol::HTTP::Request.new(
				"https",
				"localhost",
				"GET",
				"/",
				nil,
				Protocol::HTTP::Headers.new([["content-type", "text/html"]]),
				nil
			)
			
			app = proc{|_req| Protocol::HTTP::Response[200, {}, ["OK"]]}
			middleware = TestMiddleware.new(app, services: {})
			
			response = middleware.call(non_grpc_request)
			expect(response.status).to be == 200
			expect(response.body.join).to be == "OK"
		end
		
		it "returns UNIMPLEMENTED for unknown service" do
			middleware_with_empty_handler = TestMiddleware.new(services: {})
			response = middleware_with_empty_handler.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::UNIMPLEMENTED
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /Service not found/
		end
		
		it "returns UNIMPLEMENTED for unknown method" do
			# Create a handler with a service that doesn't have the method in rpc_descriptions
			handler_class = Class.new do
				def self.rpc_descriptions
					{} # Empty - no methods defined
				end
			end
			handler = handler_class.new
			services["my_service.Greeter"] = handler
			
			response = middleware.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::UNIMPLEMENTED
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /RPC descriptor not found/
		end
		
		it "calls handler method" do
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
			handler = handler_class.new
			services["my_service.Greeter"] = handler
			
			# Write a request message
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			request_data = request_message.to_proto
			prefix = [0].pack("C") + [request_data.bytesize].pack("N")
			body.write(prefix + request_data)
			body.close
			
			response = middleware.call(request)
			
			expect(response.status).to be == 200
			content_type = response.headers["content-type"]
			content_type = content_type.first if content_type.is_a?(Array)
			expect(content_type.to_s).to be == "application/grpc+proto"
			
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
		end
		
		it "handles errors gracefully" do
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
			handler = handler_class.new
			services["my_service.Greeter"] = handler
			
			body.close
			
			response = middleware.call(request)
			
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
			handler = handler_class.new
			services["my_service.Greeter"] = handler
			
			body.close
			
			response = middleware.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::NOT_FOUND
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be =~ /Not found/
		end
		
		it "uses rpc_descriptions if available" do
			handler_class = Class.new do
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
			
			handler = handler_class.new
			services["my_service.Greeter"] = handler
			
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			request_data = request_message.to_proto
			prefix = [0].pack("C") + [request_data.bytesize].pack("N")
			body.write(prefix + request_data)
			body.close
			
			response = middleware.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
		end
	end
end
