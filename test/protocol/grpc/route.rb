# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/route"

describe Protocol::GRPC::Route do
	with ".parse" do
		it "parses a gRPC request path" do
			service_name, method_name = subject.parse("/hello_v1.Greeter2/Say_Hello2")
			
			expect(service_name).to be == "hello_v1.Greeter2"
			expect(method_name).to be == "Say_Hello2"
		end
		
		it "rejects malformed paths" do
			expect do
				subject.parse("/hello.Greeter")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.parse(nil)
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.parse("/hello.Greeter/SayHello?verbose=true")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.parse("/hello%2EGreeter/SayHello")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.parse("/hello.Greeter/Say.Hello")
			end.to raise_exception(ArgumentError)
		end
	end
	
	with ".build" do
		it "builds a gRPC request path" do
			expect(subject.build("hello_v1.Greeter2", "Say_Hello2")).to be == "/hello_v1.Greeter2/Say_Hello2"
		end
		
		it "rejects invalid components" do
			expect do
				subject.build("", "SayHello")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.build("hello.Greeter", "Say/Hello")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.build("hello.Greeter", "SayHello?verbose=true")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.build("hello service.Greeter", "SayHello")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.build("hello.Greeter", "Say.Hello")
			end.to raise_exception(ArgumentError)
			
			expect do
				subject.build("_hello.Greeter", "SayHello")
			end.to raise_exception(ArgumentError)
		end
	end
end
