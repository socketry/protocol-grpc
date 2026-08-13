# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module GRPC
		module Header
			# The `grpc-timeout` header represents the gRPC request timeout.
			#
			# The `grpc-timeout` header specifies how long the client is willing to wait for an RPC to complete.
			# The format is: value + unit (H=hours, M=minutes, S=seconds, m=milliseconds, u=microseconds, n=nanoseconds).
			# This header appears only in request headers, not in trailers.
			class Timeout < String
				# Format a timeout duration for the `grpc-timeout` header.
				# @parameter timeout [Numeric] The timeout duration in seconds.
				# @returns [String] The formatted timeout.
				def self.format(timeout)
					if timeout >= 3600
						"#{(timeout / 3600).to_i}H"
					elsif timeout >= 60
						"#{(timeout / 60).to_i}M"
					elsif timeout >= 1
						"#{timeout.to_i}S"
					elsif timeout >= 0.001
						"#{(timeout * 1000).to_i}m"
					elsif timeout >= 0.000001
						"#{(timeout * 1_000_000).to_i}u"
					else
						"#{(timeout * 1_000_000_000).to_i}n"
					end
				end
				
				# Parse a timeout from a header value.
				#
				# @parameter value [String] The header value to parse (e.g., "5S", "1000m").
				# @returns [Timeout] A new Timeout instance.
				def self.parse(value)
					new(value)
				end
				
				# Coerce a value to a Timeout instance.
				#
				# If a Numeric is provided, it will be formatted as a gRPC timeout string using {format}.
				#
				# @parameter value [String | Numeric] The value to coerce.
				# @returns [Timeout] A new Timeout instance.
				def self.coerce(value)
					if value.is_a?(Numeric)
						return new(format(value))
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
					amount = self[0...-1].to_i
					unit = self[-1]
					
					case unit
					when "H" then amount * 3600
					when "M" then amount * 60
					when "S" then amount
					when "m" then amount / 1000.0
					when "u" then amount / 1_000_000.0
					when "n" then amount / 1_000_000_000.0
					end
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
