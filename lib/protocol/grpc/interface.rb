# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "methods"

module Protocol
	module GRPC
		# Wrapper class to mark a message type as streamed.
		# Used with the stream() helper method in RPC definitions.
		class Streaming
			def initialize(message_class)
				@message_class = message_class
			end
			
			# @attribute [Class] The wrapped message class
			attr :message_class
		end
		
		# Represents an interface definition for gRPC methods.
		# Can be used by both client stubs and server implementations.
		class Interface
			# RPC method definition
			RPC = Struct.new(:name, :request_class, :response_class, :streaming, :method, keyword_init: true) do
				def initialize(name:, request_class:, response_class:, streaming: :unary, method: nil)
					super
				end
				
				# Check if this RPC is a streaming RPC (server, client, or bidirectional).
				# Server-side handlers for streaming RPCs are expected to block until all messages are sent.
				# @returns [Boolean] `true` if streaming, `false` if unary
				def streaming?
					streaming != :unary
				end
			end
			
			# Helper method to mark a message type as streamed in RPC definitions.
			# Can be called directly within Interface subclasses without the Protocol::GRPC prefix.
			# @parameter message_class [Class] The message class to mark as streamed
			# @returns [Streaming] A wrapper indicating this type is streamed
			# 
			# @example Define streaming RPCs
			#   class MyService < Protocol::GRPC::Interface
			#     rpc :sum, stream(Num), Num              # client streaming
			#     rpc :fib, FibArgs, stream(Num)          # server streaming
			#     rpc :chat, stream(Msg), stream(Msg)     # bidirectional streaming
			#   end
			def self.stream(message_class)
				Streaming.new(message_class)
			end
			
			# Hook called when a subclass is created.
			# Initializes the RPC hash for the subclass.
			# @parameter subclass [Class] The subclass being created
			def self.inherited(subclass)
				super
				
				subclass.instance_variable_set(:@rpcs, {})
			end
			
			# Define an RPC method.
			# @parameter name [Symbol] Method name in PascalCase (e.g., :SayHello, matching .proto file)
			# @parameter request_class [Class | Streaming] Request message class, optionally wrapped with stream()
			# @parameter response_class [Class | Streaming] Response message class, optionally wrapped with stream()
			# @parameter streaming [Symbol] Streaming type (:unary, :server_streaming, :client_streaming, :bidirectional)
			#   This is automatically inferred from stream() decorators if not explicitly provided
			# @parameter method [Symbol | Nil] Optional explicit Ruby method name (snake_case). If not provided, automatically converts PascalCase to snake_case.
			# 
			# @example Using stream() decorator syntax
			#   rpc :div, DivArgs, DivReply                      # unary
			#   rpc :sum, stream(Num), Num                       # client streaming
			#   rpc :fib, FibArgs, stream(Num)                   # server streaming
			#   rpc :chat, stream(DivArgs), stream(DivReply)     # bidirectional streaming
			def self.rpc(name, request_class = nil, response_class = nil, **options)
				options[:name] = name
				
				# Check if request or response are wrapped with stream()
				request_streaming = request_class.is_a?(Streaming)
				response_streaming = response_class.is_a?(Streaming)
				
				# Unwrap StreamWrapper if present
				options[:request_class] ||= request_streaming ? request_class.message_class : request_class
				options[:response_class] ||= response_streaming ? response_class.message_class : response_class
				
				# Auto-detect streaming type from stream() decorators if not explicitly set
				if !options.key?(:streaming)
					if request_streaming && response_streaming
						options[:streaming] = :bidirectional
					elsif request_streaming
						options[:streaming] = :client_streaming
					elsif response_streaming
						options[:streaming] = :server_streaming
					else
						options[:streaming] = :unary
					end
				end
				
				# Ensure snake_case method name is always available
				options[:method] ||= pascal_case_to_snake_case(name.to_s).to_sym
				
				@rpcs[name] = RPC.new(**options)
			end
			
			# Look up RPC definition for a method.
			# Looks up the inheritance chain to find the RPC definition.
			# @parameter name [Symbol] Method name.
			# @returns [Protocol::GRPC::RPC | Nil] RPC definition or `Nil` if not found.
			def self.lookup_rpc(name)
				klass = self
				while klass && klass != Interface
					if klass.instance_variable_defined?(:@rpcs)
						if rpc = klass.instance_variable_get(:@rpcs)[name]
							return rpc
						end
					end
					klass = klass.superclass
				end
				
				# Not found:
				return nil
			end
			
			# Get all RPC definitions from this class and all parent classes.
			# @returns [Hash] All RPC definitions merged from inheritance chain
			def self.rpcs
				all_rpcs = {}
				klass = self
				
				# Walk up the inheritance chain:
				while klass && klass != Interface
					if klass.instance_variable_defined?(:@rpcs)
						all_rpcs.merge!(klass.instance_variable_get(:@rpcs))
					end
					klass = klass.superclass
				end
				
				all_rpcs
			end
			
			# Initialize a new interface instance.
			# @parameter name [String] Service name
			def initialize(name)
				@name = name
			end
			
			# @attribute [String] The service name (e.g., "hello.Greeter").
			attr :name
			
			# Build gRPC path for a method.
			# @parameter method_name [String, Symbol] Method name in PascalCase (e.g., :SayHello)
			# @returns [String] gRPC path with PascalCase method name
			def path(method_name)
				Methods.build_path(@name, method_name.to_s)
			end
			
		private
			
			# Convert PascalCase to snake_case.
			# @parameter pascal_case [String] PascalCase string (e.g., "SayHello")
			# @returns [String] snake_case string (e.g., "say_hello")
			def self.pascal_case_to_snake_case(pascal_case)
				pascal_case
					.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')  # Insert underscore before capital letters followed by lowercase
					.gsub(/([a-z\d])([A-Z])/, '\1_\2')      # Insert underscore between lowercase/digit and uppercase
					.downcase
			end
		end
	end
end
