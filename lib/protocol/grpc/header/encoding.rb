# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module GRPC
		module Header
			# The `grpc-encoding` header represents the message compression encoding.
			#
			# The `grpc-encoding` header specifies the compression algorithm used for the message payload.
			# Common values include "identity" (no compression), "gzip", "deflate", etc.
			# This header can appear in both request and response headers, but not in trailers.
			class Encoding < String
				# Parse an encoding from a header value.
				#
				# @parameter value [String] The header value to parse (e.g., "identity", "gzip").
				# @returns [Encoding] A new Encoding instance.
				def self.parse(value)
					new(value)
				end
				
				def self.coerce(value)
					new(value.to_s)
				end
				
				# Initialize the encoding header with the given value.
				#
				# @parameter value [String] The encoding value (e.g., "identity", "gzip").
				def initialize(value)
					super(value.to_s)
				end
				
				# Check if this encoding represents no compression (identity encoding).
				#
				# @returns [Boolean] `true` if the encoding is "identity" or empty.
				def identity?
					self == "identity" || self.empty?
				end
				
				# Merge another encoding value (takes the new value, as encoding should only appear once)
				# @parameter value [String] The new encoding value
				def <<(value)
					replace(value.to_s)
					
					return self
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-encoding` header does not appear in trailers.
				# @returns [Boolean] `false`, as grpc-encoding cannot appear in trailers.
				def self.trailer?
					false
				end
			end
		end
	end
end
