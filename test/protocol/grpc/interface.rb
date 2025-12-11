# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/interface"

describe Protocol::GRPC::Interface do
	let(:request_class) {Class.new}
	let(:response_class) {Class.new}
	
	it "can define and retrieve RPC methods" do
		request_class = self.request_class
		response_class = self.response_class
		
		interface_class = Class.new(Protocol::GRPC::Interface) do
			rpc :SayHello, request_class: request_class, response_class: response_class
		end
		
		rpc = interface_class.lookup_rpc(:SayHello)
		expect(rpc.name).to be == :SayHello
		expect(rpc.method).to be == :say_hello
		expect(rpc.request_class).to be == request_class
		expect(rpc.response_class).to be == response_class
		expect(rpc.streaming).to be == :unary
		expect(rpc.streaming?).to be == false
	end
	
	it "returns nil for undefined RPC methods" do
		interface_class = Class.new(Protocol::GRPC::Interface)
		
		expect(interface_class.lookup_rpc(:unknown)).to be_nil
	end
	
	it "can retrieve all RPCs" do
		request_class = self.request_class
		response_class = self.response_class
		
		interface_class = Class.new(Protocol::GRPC::Interface) do
			rpc :Method1, request_class: request_class, response_class: response_class
			rpc :Method2, request_class: request_class, response_class: response_class, streaming: :server_streaming
		end
		
		rpcs = interface_class.rpcs
		expect(rpcs.keys.sort).to be == [:Method1, :Method2].sort
		expect(rpcs[:Method1].streaming).to be == :unary
		expect(rpcs[:Method2].streaming).to be == :server_streaming
		
		# Test streaming? method:
		expect(rpcs[:Method1].streaming?).to be == false
		expect(rpcs[:Method2].streaming?).to be == true
	end
	
	it "inherits RPCs from parent class" do
		request_class = self.request_class
		response_class = self.response_class
		
		base_class = Class.new(Protocol::GRPC::Interface) do
			rpc :BaseMethod, request_class: request_class, response_class: response_class
		end
		
		subclass = Class.new(base_class) do
			rpc :SubMethod, request_class: request_class, response_class: response_class
		end
		
		# Subclass should have both methods
		expect(subclass.rpcs.keys.sort).to be == [:BaseMethod, :SubMethod].sort
		
		# Can retrieve inherited method
		base_rpc = subclass.lookup_rpc(:BaseMethod)
		expect(base_rpc.request_class).to be == request_class
		expect(base_rpc.response_class).to be == response_class
		
		# Can retrieve own method
		sub_rpc = subclass.lookup_rpc(:SubMethod)
		expect(sub_rpc.request_class).to be == request_class
		expect(sub_rpc.response_class).to be == response_class
	end
	
	it "can override RPCs in subclass" do
		request_class = self.request_class
		response_class = self.response_class
		other_request_class = Class.new
		other_response_class = Class.new
		
		base_class = Class.new(Protocol::GRPC::Interface) do
			rpc :Method, request_class: request_class, response_class: response_class
		end
		
		subclass = Class.new(base_class) do
			rpc :Method, request_class: other_request_class, response_class: other_response_class, streaming: :bidirectional
		end
		
		# Subclass should use its own definition
		rpc = subclass.lookup_rpc(:Method)
		expect(rpc.request_class).to be == other_request_class
		expect(rpc.response_class).to be == other_response_class
		expect(rpc.streaming).to be == :bidirectional
		expect(rpc.streaming?).to be == true
		
		# Base class should still have original definition
		base_rpc = base_class.lookup_rpc(:Method)
		expect(base_rpc.request_class).to be == request_class
		expect(base_rpc.response_class).to be == response_class
		expect(base_rpc.streaming).to be == :unary
		expect(base_rpc.streaming?).to be == false
	end
	
	it "supports multiple levels of inheritance" do
		request_class = self.request_class
		response_class = self.response_class
		
		level1 = Class.new(Protocol::GRPC::Interface) do
			rpc :Level1Method, request_class: request_class, response_class: response_class
		end
		
		level2 = Class.new(level1) do
			rpc :Level2Method, request_class: request_class, response_class: response_class
		end
		
		level3 = Class.new(level2) do
			rpc :Level3Method, request_class: request_class, response_class: response_class
		end
		
		# Level 3 should have all methods
		expect(level3.rpcs.keys.sort).to be == [:Level1Method, :Level2Method, :Level3Method].sort
		
		# Can retrieve methods from all levels
		expect(level3.lookup_rpc(:Level1Method)).not.to be_nil
		expect(level3.lookup_rpc(:Level2Method)).not.to be_nil
		expect(level3.lookup_rpc(:Level3Method)).not.to be_nil
	end
	
	it "can build paths for methods" do
		interface = Protocol::GRPC::Interface.new("hello.Greeter")
		
		expect(interface.path("SayHello")).to be == "/hello.Greeter/SayHello"
		expect(interface.path(:say_hello)).to be == "/hello.Greeter/say_hello"
	end
	
	it "maintains separate RPC definitions for different classes" do
		request_class = self.request_class
		response_class = self.response_class
		
		class1 = Class.new(Protocol::GRPC::Interface) do
			rpc :Method1, request_class: request_class, response_class: response_class
		end
		
		class2 = Class.new(Protocol::GRPC::Interface) do
			rpc :Method2, request_class: request_class, response_class: response_class
		end
		
		# Each class should only have its own RPCs
		expect(class1.rpcs.keys).to be == [:Method1]
		expect(class2.rpcs.keys).to be == [:Method2]
		
		expect(class1.lookup_rpc(:Method2)).to be_nil
		expect(class2.lookup_rpc(:Method1)).to be_nil
	end
	
	it "supports explicit method name in RPC definition" do
		request_class = self.request_class
		response_class = self.response_class
		
		# Create interface with explicit method name
		explicit_interface = Class.new(Protocol::GRPC::Interface) do
			rpc :XMLParser, request_class: request_class, response_class: response_class,
				method: :xml_parser
		end
		
		rpc = explicit_interface.lookup_rpc(:XMLParser)
		expect(rpc).to be_a(Protocol::GRPC::Interface::RPC)
		expect(rpc.name).to be == :XMLParser
		expect(rpc.method).to be == :xml_parser
		expect(rpc.request_class).to be == request_class
		expect(rpc.response_class).to be == response_class
	end
	
	with "method field auto-conversion" do
		it "always sets method field when not explicitly provided" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :SayHello, request_class: request_class, response_class: response_class
			end
			
			rpc = interface_class.lookup_rpc(:SayHello)
			expect(rpc.name).to be == :SayHello
			expect(rpc.method).not.to be_nil
			expect(rpc.method).to be == :say_hello
		end
		
		it "converts PascalCase to snake_case correctly" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :SayHello, request_class: request_class, response_class: response_class
				rpc :UnaryCall, request_class: request_class, response_class: response_class
				rpc :ServerStreamingCall, request_class: request_class, response_class: response_class
				rpc :XMLParser, request_class: request_class, response_class: response_class
			end
			
			expect(interface_class.lookup_rpc(:SayHello).name).to be == :SayHello
			expect(interface_class.lookup_rpc(:SayHello).method).to be == :say_hello
			expect(interface_class.lookup_rpc(:UnaryCall).name).to be == :UnaryCall
			expect(interface_class.lookup_rpc(:UnaryCall).method).to be == :unary_call
			expect(interface_class.lookup_rpc(:ServerStreamingCall).name).to be == :ServerStreamingCall
			expect(interface_class.lookup_rpc(:ServerStreamingCall).method).to be == :server_streaming_call
			expect(interface_class.lookup_rpc(:XMLParser).name).to be == :XMLParser
			expect(interface_class.lookup_rpc(:XMLParser).method).to be == :xml_parser
		end
		
		it "uses explicit method name when provided" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :SayHello, request_class: request_class, response_class: response_class,
					method: :greet_user
				rpc :XMLParser, request_class: request_class, response_class: response_class,
					method: :parse_xml
			end
			
			expect(interface_class.lookup_rpc(:SayHello).name).to be == :SayHello
			expect(interface_class.lookup_rpc(:SayHello).method).to be == :greet_user
			expect(interface_class.lookup_rpc(:XMLParser).name).to be == :XMLParser
			expect(interface_class.lookup_rpc(:XMLParser).method).to be == :parse_xml
		end
		
		it "ensures method field is never nil" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :SayHello, request_class: request_class, response_class: response_class
				rpc :UnaryCall, request_class: request_class, response_class: response_class,
					method: :unary_call
			end
			
			# Both should have method set
			rpc1 = interface_class.lookup_rpc(:SayHello)
			rpc2 = interface_class.lookup_rpc(:UnaryCall)
			
			expect(rpc1.name).to be == :SayHello
			expect(rpc2.name).to be == :UnaryCall
			expect(rpc1.method).not.to be_nil
			expect(rpc2.method).not.to be_nil
			expect(rpc1.method).to be_a(Symbol)
			expect(rpc2.method).to be_a(Symbol)
		end
		
		it "handles edge cases in PascalCase conversion" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :HTTPRequest, request_class: request_class, response_class: response_class
				rpc :XMLHTTPRequest, request_class: request_class, response_class: response_class
				rpc :GetUserByID, request_class: request_class, response_class: response_class
			end
			
			expect(interface_class.lookup_rpc(:HTTPRequest).name).to be == :HTTPRequest
			expect(interface_class.lookup_rpc(:HTTPRequest).method).to be == :http_request
			expect(interface_class.lookup_rpc(:XMLHTTPRequest).name).to be == :XMLHTTPRequest
			expect(interface_class.lookup_rpc(:XMLHTTPRequest).method).to be == :xmlhttp_request
			expect(interface_class.lookup_rpc(:GetUserByID).name).to be == :GetUserByID
			expect(interface_class.lookup_rpc(:GetUserByID).method).to be == :get_user_by_id
		end
	end
	
	with "name field" do
		it "always sets name field to the RPC definition name" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :SayHello, request_class: request_class, response_class: response_class
				rpc :UnaryCall, request_class: request_class, response_class: response_class
				rpc :XMLParser, request_class: request_class, response_class: response_class,
					method: :xml_parser
			end
			
			expect(interface_class.lookup_rpc(:SayHello).name).to be == :SayHello
			expect(interface_class.lookup_rpc(:UnaryCall).name).to be == :UnaryCall
			expect(interface_class.lookup_rpc(:XMLParser).name).to be == :XMLParser
		end
		
		it "preserves name even when method is explicitly set" do
			request_class = self.request_class
			response_class = self.response_class
			
			interface_class = Class.new(Protocol::GRPC::Interface) do
				rpc :SayHello, request_class: request_class, response_class: response_class,
					method: :greet_user
			end
			
			rpc = interface_class.lookup_rpc(:SayHello)
			expect(rpc.name).to be == :SayHello
			expect(rpc.method).to be == :greet_user
		end
	end
end
