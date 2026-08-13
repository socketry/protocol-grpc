# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

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
	
	with "#make_response" do
		# Create a test middleware that exposes make_response for testing
		let(:test_middleware) do
			Class.new(Protocol::GRPC::Middleware) do
				public :make_response
			end.new
		end
		
		it "creates a response with status and message" do
			response = test_middleware.make_response(
				Protocol::GRPC::Status::NOT_FOUND,
				"Resource not found"
			)
			
			expect(response.status).to be == 200
			expect(response.headers["content-type"]).to be == "application/grpc+proto"
			
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::NOT_FOUND
			
			message = Protocol::GRPC::Metadata.extract_message(response.headers)
			expect(message).to be == "Resource not found"
		end
		
		it "adds backtrace to headers when error has backtrace" do
			error = StandardError.new("Test error")
			error.set_backtrace([
				"/path/to/file.rb:10:in `method'",
				"/path/to/file.rb:5:in `block'"
			])
			
			response = test_middleware.make_response(
				Protocol::GRPC::Status::INTERNAL,
				"Internal error",
				error: error
			)
			
			# Access backtrace directly from headers (Split header returns array)
			backtrace = response.headers["backtrace"]
			
			expect(backtrace).to be_a(Array)
			expect(backtrace.length).to be == 2
			expect(backtrace[0]).to be == "/path/to/file.rb:10:in `method'"
			expect(backtrace[1]).to be == "/path/to/file.rb:5:in `block'"
			
			# Also verify it's accessible via extract_metadata (for client-side usage)
			metadata = Protocol::GRPC::Methods.extract_metadata(response.headers)
			backtrace_from_metadata = metadata["backtrace"]
			# extract_metadata may return string or array depending on how headers.each works
			# But the important thing is that it's present and can be parsed
			expect(backtrace_from_metadata).not.to be_nil
		end
		
		it "does not add backtrace when error has no backtrace" do
			error = StandardError.new("Test error")
			# Don't set backtrace
			
			response = test_middleware.make_response(
				Protocol::GRPC::Status::INTERNAL,
				"Internal error",
				error: error
			)
			
			metadata = Protocol::GRPC::Methods.extract_metadata(response.headers)
			expect(metadata.key?("backtrace")).to be == false
		end
		
		it "does not add backtrace when error is nil" do
			response = test_middleware.make_response(
				Protocol::GRPC::Status::INTERNAL,
				"Internal error",
				error: nil
			)
			
			metadata = Protocol::GRPC::Methods.extract_metadata(response.headers)
			expect(metadata.key?("backtrace")).to be == false
		end
		
		it "does not add backtrace when error has empty backtrace" do
			error = StandardError.new("Test error")
			error.set_backtrace([])
			
			response = test_middleware.make_response(
				Protocol::GRPC::Status::INTERNAL,
				"Internal error",
				error: error
			)
			
			metadata = Protocol::GRPC::Methods.extract_metadata(response.headers)
			expect(metadata.key?("backtrace")).to be == false
		end
		
		it "handles backtrace through error handling flow" do
			# Use the same request setup as the parent context
			test_headers = Protocol::HTTP::Headers.new([
				["content-type", "application/grpc+proto"]
			])
			test_body = Protocol::HTTP::Body::Buffered.new
			test_request = Protocol::HTTP::Request.new(
				"https",
				"localhost",
				"POST",
				"/my_service.Greeter/SayHello",
				nil,
				test_headers,
				test_body
			)
			
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
					error = StandardError.new("Handler error")
					error.set_backtrace([
						"/handler.rb:5:in `say_hello'",
						"/handler.rb:2:in `call'"
					])
					raise error
				end
			end
			handler = handler_class.new
			services["my_service.Greeter"] = handler
			
			test_body.close
			
			response = middleware.call(test_request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::INTERNAL
			
			# Verify backtrace is accessible directly from headers
			backtrace = response.headers["backtrace"]
			expect(backtrace).to be_a(Array)
			expect(backtrace.length).to be == 2
			expect(backtrace[0]).to be == "/handler.rb:5:in `say_hello'"
			expect(backtrace[1]).to be == "/handler.rb:2:in `call'"
		end
	end
	
	with "grpc-timeout header" do
		let(:handler_class) do
			Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage
						}
					}
				end
				
				def say_hello(input, output, call)
					if deadline = call.deadline
						message = Protocol::GRPC::Fixtures::TestMessage.new(value: deadline.remaining.to_s)
					else
						message = Protocol::GRPC::Fixtures::TestMessage.new(value: "Hello")
					end
					
					output.write(message)
				end
			end
		end
		
		let(:handler) {handler_class.new}
		let(:services) {{"my_service.Greeter" => handler}}
		let(:middleware) {TestMiddleware.new(services: services)}
		
		let(:headers) do
			Protocol::HTTP::Headers.new([
				["content-type", "application/grpc+proto"],
				["grpc-timeout", "5S"]
			])
		end
		
		let(:body) {Protocol::GRPC::Body::Writable.new(message_class: Protocol::GRPC::Fixtures::TestMessage)}
		
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
		
		it "parses grpc-timeout header and sets deadline" do
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			body.write(request_message)
			body.close
			
			response = middleware.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
			
			response_body = Protocol::GRPC::Body::Readable.new(response.body, message_class: Protocol::GRPC::Fixtures::TestMessage)
			message = response_body.read
			expect(message).to be_a(Protocol::GRPC::Fixtures::TestMessage)
			
			remaining = Float(message.value)
			expect(remaining).to be <= 5.0
		end
	end
	
	with "grpc-encoding header" do
		let(:handler_class) do
			Class.new do
				def self.rpc_descriptions
					{
						"SayHello" => {
							method: :say_hello,
							request_class: Protocol::GRPC::Fixtures::TestMessage,
							response_class: Protocol::GRPC::Fixtures::TestMessage
						}
					}
				end
				
				def say_hello(input, output, call)
					message = Protocol::GRPC::Fixtures::TestMessage.new(value: "Hello" * 100)
					output.write(message)
				end
			end
		end
		
		let(:handler) {handler_class.new}
		let(:services) {{"my_service.Greeter" => handler}}
		let(:middleware) {TestMiddleware.new(services: services)}
		
		let(:headers) do
			Protocol::HTTP::Headers.new([
				["content-type", "application/grpc+proto"],
				["grpc-encoding", "gzip"]
			])
		end
		
		let(:body) {Protocol::GRPC::Body::Writable.new(message_class: Protocol::GRPC::Fixtures::TestMessage)}
		
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
		
		it "passes grpc-encoding header to input and output" do
			request_message = Protocol::GRPC::Fixtures::TestMessage.new(value: "World")
			body.write(request_message)
			body.close
			
			response = middleware.call(request)
			
			expect(response.status).to be == 200
			status = Protocol::GRPC::Metadata.extract_status(response.headers)
			expect(status).to be == Protocol::GRPC::Status::OK
			
			# Verify encoding is echoed in response headers
			# The header policy converts strings to Header::Encoding instances
			encoding = response.headers["grpc-encoding"]
			expect(encoding).not.to be_nil
			expect(encoding.to_s).to be == "gzip"
			
			response_body = Protocol::GRPC::Body::Readable.new(response.body, message_class: Protocol::GRPC::Fixtures::TestMessage, encoding: encoding)
			message = response_body.read
			expect(message).to be_a(Protocol::GRPC::Fixtures::TestMessage)
			expect(message.value).to be == "Hello" * 100
		end
	end
end
