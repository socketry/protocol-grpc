# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http"
require "uri"

require_relative "status"

module Protocol
	module GRPC
		module Header
			# The `grpc-status` header represents the gRPC status code.
			#
			# The `grpc-status` header contains a numeric status code (0-16) indicating the result of the RPC call.
			# Status code 0 indicates success (OK), while other codes indicate various error conditions.
			# This header can appear both as an initial header (for trailers-only responses) and as a trailer.
			class Status
				# Initialize the status header with the given value.
				#
				# @parameter value [String, Integer] The status code as a string or integer.
				def initialize(value)
					@value = value.is_a?(String) ? value.to_i : value.to_i
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
					@value = value.is_a?(String) ? value.to_i : value.to_i
					self
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-status` header can appear in trailers as per the gRPC specification.
				# @returns [Boolean] `true`, as grpc-status can appear in trailers.
				def self.trailer?
					true
				end
			end
			
			# The `grpc-message` header represents the gRPC status message.
			#
			# The `grpc-message` header contains a human-readable error message, URL-encoded according to RFC 3986.
			# This header is optional and typically only present when there's an error (non-zero status code).
			# This header can appear both as an initial header (for trailers-only responses) and as a trailer.
			class Message < String
				# Initialize the message header with the given value.
				#
				# @parameter value [String] The message value (will be URL-encoded if not already encoded).
				def initialize(value)
					super(value.to_s)
				end
				
				# Decode the URL-encoded message.
				#
				# @returns [String] The decoded message.
				def decode
					URI.decode_www_form_component(self)
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
					self
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-message` header can appear in trailers as per the gRPC specification.
				# @returns [Boolean] `true`, as grpc-message can appear in trailers.
				def self.trailer?
					true
				end
			end
			
			# Base class for custom gRPC metadata (allowed in trailers).
			class Metadata < Protocol::HTTP::Header::Split
				def self.trailer?
					true
				end
			end
		end
		
		# Custom header policy for gRPC.
		# Extends Protocol::HTTP::Headers::POLICY with gRPC-specific headers.
		HEADER_POLICY = Protocol::HTTP::Headers::POLICY.merge(
			"grpc-status" => Header::Status,
			"grpc-message" => Header::Message
			# By default, all other headers follow standard HTTP policy, but gRPC allows most metadata to be sent as trailers.
		).freeze
	end
end
