# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "uri"

module Protocol
	module GRPC
		module Header
			# The `grpc-message` header represents the gRPC status message.
			#
			# The `grpc-message` header contains a human-readable error message, URL-encoded according to RFC 3986.
			# This header is optional and typically only present when there's an error (non-zero status code).
			# This header can appear both as an initial header (for trailers-only responses) and as a trailer.
			class Message < String
				# Parse a message from a header value.
				#
				# @parameter value [String] The header value to parse.
				# @returns [Message] A new Message instance.
				def self.parse(value)
					new(value)
				end
				
				# Initialize the message header with the given value.
				#
				# @parameter value [String] The message value (will be URL-encoded if not already encoded).
				def initialize(value)
					super(value)
				end
				
				# Decode the URL-encoded message.
				#
				# @returns [String] The decoded message.
				def decode
					::URI.decode_www_form_component(self)
				end
				
				# Encode the message for use in headers.
				#
				# @parameter message [String] The message to encode.
				# @returns [String] The URL-encoded message.
				def self.encode(message)
					URI.encode_www_form_component(message).gsub("+", "%20")
				end
				
				# Merge another message value (takes the new value, as message should only appear once)
				# @parameter value [String] The new message value
				def <<(value)
					replace(value.to_s)
					
					return self
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-message` header can appear in trailers as per the gRPC specification.
				# @returns [Boolean] `true`, as grpc-message can appear in trailers.
				def self.trailer?
					true
				end
			end
		end
	end
end
