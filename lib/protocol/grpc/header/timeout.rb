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
				# The wire format for a gRPC timeout value.
				FORMAT = /\A(?<amount>\d{1,8})(?<unit>[HMSmun])\z/
				
				# Format a timeout duration for the `grpc-timeout` header.
				# @parameter timeout [Numeric] The timeout duration in seconds.
				# @returns [String] The formatted timeout.
				def self.format(timeout)
					raise ArgumentError, "Timeout must be finite and non-negative" unless timeout.finite? && timeout >= 0
					raise RangeError, "Timeout exceeds the grpc-timeout wire limit" if timeout > 99_999_999 * 3600
					return "0n" if timeout.zero?
					
					nanoseconds = (timeout * 1_000_000_000).ceil
					units = {"H" => 3_600_000_000_000, "M" => 60_000_000_000, "S" => 1_000_000_000, "m" => 1_000_000, "u" => 1000, "n" => 1}
					
					# Prefer an exact representation in the largest possible unit:
					units.each do |unit, scale|
						amount, remainder = nanoseconds.divmod(scale)
						return "#{amount}#{unit}" if remainder.zero? && amount <= 99_999_999
					end
					
					# Otherwise round up in the finest unit that fits the wire limit:
					units.reverse_each do |unit, scale|
						amount = (nanoseconds + scale - 1).div(scale)
						return "#{amount}#{unit}" if amount <= 99_999_999
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
				# @returns [Numeric] Timeout in seconds.
				# @raises [ArgumentError] If the timeout value is invalid.
				def to_seconds
					unless match = FORMAT.match(self)
						raise ArgumentError, "Invalid grpc-timeout: #{self.inspect}"
					end
					
					amount = match[:amount].to_i
					
					case match[:unit]
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
