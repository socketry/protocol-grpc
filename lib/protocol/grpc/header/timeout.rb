# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../methods"

module Protocol
	module GRPC
		module Header
			# The `grpc-timeout` header represents the gRPC request timeout.
			#
			# The `grpc-timeout` header specifies how long the client is willing to wait for an RPC to complete.
			# The format is: value + unit (H=hours, M=minutes, S=seconds, m=milliseconds, u=microseconds, n=nanoseconds).
			# This header appears only in request headers, not in trailers.
			class Timeout < String
				# Parse a timeout from a header value.
				#
				# @parameter value [String] The header value to parse (e.g., "5S", "1000m").
				# @returns [Timeout] A new Timeout instance.
				def self.parse(value)
					new(value)
				end
				
				def self.coerce(value)
					if value.is_a?(Numeric)
						return new(Protocol::GRPC::Methods.format_timeout(value))
					else
						return new(value.to_s)
					end
				end
				
				# Initialize the timeout header with the given value.
				#
				# @parameter value [String] The timeout value in gRPC format.
				def initialize(value)
					super(value.to_s)
				end
				
				# Parse the timeout value to seconds.
				#
				# @returns [Numeric | Nil] Timeout in seconds, or `Nil` if value is invalid.
				def to_seconds
					Protocol::GRPC::Methods.parse_timeout(self)
				end
				
				# Merge another timeout value (takes the new value, as timeout should only appear once)
				# @parameter value [String] The new timeout value
				def <<(value)
					replace(value.to_s)
					
					return self
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-timeout` header is request-only and does not appear in trailers.
				# @returns [Boolean] `false`, as grpc-timeout cannot appear in trailers.
				def self.trailer?
					false
				end
			end
		end
	end
end
