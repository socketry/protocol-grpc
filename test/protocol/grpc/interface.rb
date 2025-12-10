# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/interface"

describe Protocol::GRPC::Interface do
	let(:request_class) {Class.new}
	let(:response_class) {Class.new}
	
	it "can define and retrieve RPC methods" do
		req_class = request_class
		res_class = response_class
		
		interface_class = Class.new(Protocol::GRPC::Interface) do
			rpc :say_hello, request_class: req_class, response_class: res_class
		end
		
		rpc = interface_class.lookup_rpc(:say_hello)
		expect(rpc.request_class).to be == request_class
		expect(rpc.response_class).to be == response_class
		expect(rpc.streaming).to be == :unary
	end
	
	it "returns nil for undefined RPC methods" do
		interface_class = Class.new(Protocol::GRPC::Interface)
		
		expect(interface_class.lookup_rpc(:unknown)).to be_nil
	end
	
	it "can retrieve all RPCs" do
		req_class = request_class
		res_class = response_class
		
		interface_class = Class.new(Protocol::GRPC::Interface) do
			rpc :method1, request_class: req_class, response_class: res_class
			rpc :method2, request_class: req_class, response_class: res_class, streaming: :server_streaming
		end
		
		rpcs = interface_class.rpcs
		expect(rpcs.keys.sort).to be == [:method1, :method2].sort
		expect(rpcs[:method1].streaming).to be == :unary
		expect(rpcs[:method2].streaming).to be == :server_streaming
	end
	
	it "inherits RPCs from parent class" do
		req_class = request_class
		res_class = response_class
		
		base_class = Class.new(Protocol::GRPC::Interface) do
			rpc :base_method, request_class: req_class, response_class: res_class
		end
		
		subclass = Class.new(base_class) do
			rpc :sub_method, request_class: req_class, response_class: res_class
		end
		
		# Subclass should have both methods
		expect(subclass.rpcs.keys.sort).to be == [:base_method, :sub_method].sort
		
		# Can retrieve inherited method
		base_rpc = subclass.lookup_rpc(:base_method)
		expect(base_rpc.request_class).to be == request_class
		expect(base_rpc.response_class).to be == response_class
		
		# Can retrieve own method
		sub_rpc = subclass.lookup_rpc(:sub_method)
		expect(sub_rpc.request_class).to be == request_class
		expect(sub_rpc.response_class).to be == response_class
	end
	
	it "can override RPCs in subclass" do
		req_class = request_class
		res_class = response_class
		other_request_class = Class.new
		other_response_class = Class.new
		
		base_class = Class.new(Protocol::GRPC::Interface) do
			rpc :method, request_class: req_class, response_class: res_class
		end
		
		subclass = Class.new(base_class) do
			rpc :method, request_class: other_request_class, response_class: other_response_class, streaming: :bidirectional
		end
		
		# Subclass should use its own definition
		rpc = subclass.lookup_rpc(:method)
		expect(rpc.request_class).to be == other_request_class
		expect(rpc.response_class).to be == other_response_class
		expect(rpc.streaming).to be == :bidirectional
		
		# Base class should still have original definition
		base_rpc = base_class.lookup_rpc(:method)
		expect(base_rpc.request_class).to be == request_class
		expect(base_rpc.response_class).to be == response_class
		expect(base_rpc.streaming).to be == :unary
	end
	
	it "supports multiple levels of inheritance" do
		req_class = request_class
		res_class = response_class
		
		level1 = Class.new(Protocol::GRPC::Interface) do
			rpc :level1_method, request_class: req_class, response_class: res_class
		end
		
		level2 = Class.new(level1) do
			rpc :level2_method, request_class: req_class, response_class: res_class
		end
		
		level3 = Class.new(level2) do
			rpc :level3_method, request_class: req_class, response_class: res_class
		end
		
		# Level 3 should have all methods
		expect(level3.rpcs.keys.sort).to be == [:level1_method, :level2_method, :level3_method].sort
		
		# Can retrieve methods from all levels
		expect(level3.lookup_rpc(:level1_method)).not.to be_nil
		expect(level3.lookup_rpc(:level2_method)).not.to be_nil
		expect(level3.lookup_rpc(:level3_method)).not.to be_nil
	end
	
	it "can build paths for methods" do
		interface = Protocol::GRPC::Interface.new("hello.Greeter")
		
		expect(interface.path("SayHello")).to be == "/hello.Greeter/SayHello"
		expect(interface.path(:say_hello)).to be == "/hello.Greeter/say_hello"
	end
	
	it "maintains separate RPC definitions for different classes" do
		req_class = request_class
		res_class = response_class
		
		class1 = Class.new(Protocol::GRPC::Interface) do
			rpc :method1, request_class: req_class, response_class: res_class
		end
		
		class2 = Class.new(Protocol::GRPC::Interface) do
			rpc :method2, request_class: req_class, response_class: res_class
		end
		
		# Each class should only have its own RPCs
		expect(class1.rpcs.keys).to be == [:method1]
		expect(class2.rpcs.keys).to be == [:method2]
		
		expect(class1.lookup_rpc(:method2)).to be_nil
		expect(class2.lookup_rpc(:method1)).to be_nil
	end
	
	it "supports explicit method name in RPC definition" do
		req_class = request_class
		res_class = response_class
		
		# Create interface with explicit method name
		explicit_interface = Class.new(Protocol::GRPC::Interface) do
			rpc :XMLParser, request_class: req_class, response_class: res_class,
				method: :xml_parser
		end
		
		rpc = explicit_interface.lookup_rpc(:XMLParser)
		expect(rpc).to be_a(Protocol::GRPC::RPC)
		expect(rpc.method).to be == :xml_parser
		expect(rpc.request_class).to be == req_class
		expect(rpc.response_class).to be == res_class
	end
end

