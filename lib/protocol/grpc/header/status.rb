# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module GRPC
		module Header
			# The `grpc-status` header represents the gRPC status code.
			#
			# The `grpc-status` header contains a numeric status code (0-16) indicating the result of the RPC call.
			# Status code 0 indicates success (OK), while other codes indicate various error conditions.
			# This header can appear both as an initial header (for trailers-only responses) and as a trailer.
			class Status
				def self.parse(value)
					new(value.to_i)
				end
				
				# Initialize the status header with the given value.
				#
				# @parameter value [String, Integer] The status code as a string or integer.
				def initialize(value)
					@value = value.to_i
				end
				
				# Get the status code as an integer.
				#
				# @returns [Integer] The status code.
				def to_i
					@value
				end
				
				# Serialize the status code to a string.
				#
				# @returns [String] The status code as a string.
				def to_s
					@value.to_s
				end
				
				# Merge another status value (takes the new value, as status should only appear once)
			# @parameter value [String, Integer] The new status code
				def <<(value)
					@value = value.to_i
					
					return self
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-status` header can appear in trailers as per the gRPC specification.
				# @returns [Boolean] `true`, as grpc-status can appear in trailers.
				def self.trailer?
					true
				end
			end
		end
	end
end
