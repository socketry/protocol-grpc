# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "methods"

module Protocol
	module GRPC
		# RPC method definition
		RPC = Struct.new(:request_class, :response_class, :streaming, :method, keyword_init: true) do
			def initialize(request_class:, response_class:, streaming: :unary, method: nil)
				super
			end
		end
		
		# Interface definition for gRPC methods
		# Can be used by both client stubs and server implementations
		class Interface
			# Hook called when a subclass is created
			# Initializes the RPC hash for the subclass
			def self.inherited(subclass)
				super
				
				subclass.instance_variable_set(:@rpcs, {})
			end
			
			# Define an RPC method
			# @parameter name [Symbol] Method name in PascalCase (e.g., :SayHello, matching .proto file)
			# @parameter request_class [Class] Request message class
			# @parameter response_class [Class] Response message class
			# @parameter streaming [Symbol] Streaming type (:unary, :server_streaming, :client_streaming, :bidirectional)
			# @parameter method [Symbol, nil] Optional explicit Ruby method name (snake_case). If not provided, automatically converts PascalCase to snake_case.
			def self.rpc(name, **options)
				@rpcs[name] = RPC.new(**options)
			end
			
			# Look up RPC definition for a method.
			# Looks up the inheritance chain to find the RPC definition.
			# @parameter name [Symbol] Method name.
			# @returns [Protocol::GRPC::RPC, nil] RPC definition or nil if not found.
			def self.lookup_rpc(name)
				klass = self
				while klass && klass != Interface
					if klass.instance_variable_defined?(:@rpcs)
						rpc = klass.instance_variable_get(:@rpcs)[name]
						return rpc if rpc
					end
					klass = klass.superclass
				end
				nil
			end
			
			# Get all RPC definitions from this class and all parent classes
			# @returns [Hash] All RPC definitions merged from inheritance chain
			def self.rpcs
				all_rpcs = {}
				klass = self
				
				# Walk up the inheritance chain
				while klass && klass != Interface
					if klass.instance_variable_defined?(:@rpcs)
						all_rpcs.merge!(klass.instance_variable_get(:@rpcs))
					end
					klass = klass.superclass
				end
				
				all_rpcs
			end
			
			# Service name (e.g., "hello.Greeter")
			# @attribute [String]
			attr :name
			
			# @parameter name [String] Service name
			def initialize(name)
				@name = name
			end
			
			# Build path for a method
			# @parameter method_name [String, Symbol] Method name in PascalCase (e.g., :SayHello)
			# @returns [String] gRPC path with PascalCase method name
			def path(method_name)
				Methods.build_path(@name, method_name.to_s)
			end
		end
	end
end
