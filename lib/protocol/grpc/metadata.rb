# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "base64"

require_relative "header"
require_relative "status"

module Protocol
	module GRPC
		# Provides operations for building and extracting gRPC metadata.
		module Metadata
			# Build gRPC request headers containing the given metadata.
			# @parameter metadata [Hash] Custom metadata key-value pairs.
			# @parameter timeout [Numeric | Nil] Optional timeout in seconds.
			# @parameter content_type [String] The request content type.
			# @returns [Protocol::HTTP::Headers] The constructed request headers.
			def self.build(metadata: {}, timeout: nil, content_type: "application/grpc+proto")
				headers = Protocol::HTTP::Headers.new(policy: Protocol::GRPC::HEADER_POLICY)
				headers["content-type"] = content_type
				headers["te"] = "trailers"
				
				if timeout
					# Coerced to proper format by header policy:
					headers["grpc-timeout"] = timeout
				end
				
				metadata.each do |key, value|
					# Binary headers end with -bin and are base64 encoded:
					headers[key] = if key.end_with?("-bin")
						Base64.strict_encode64(value)
					else
						value.to_s
					end
				end
				
				headers
			end
			
			# Extract application metadata from gRPC headers.
			# @parameter headers [Protocol::HTTP::Headers] The headers to inspect.
			# @returns [Hash] The extracted metadata key-value pairs.
			def self.extract(headers)
				metadata = {}
				
				headers.to_h.each do |key, value|
					# Skip reserved headers:
					next if key.start_with?("grpc-") || key == "content-type" || key == "te"
					
					# Decode binary headers:
					if key.end_with?("-bin")
						if value.is_a?(String)
							value = Base64.strict_decode64(value)
						elsif value.is_a?(Array)
							value = value.map{|item| Base64.strict_decode64(item)}
						end
					end
					
					metadata[key] = value
				end
				
				metadata
			end
			
			# Extract gRPC status from headers.
			# Returns Status::UNKNOWN if status is not present.
			#
			# Note: In Protocol::HTTP::Headers, trailers are merged into the headers
			# so users just access headers["grpc-status"] regardless of whether it
			# was sent as an initial header or trailer.
			#
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Integer] Status code (0-16)
			def self.extract_status(headers)
				# Ensure policy is set - setting policy clears the index (@indexed = nil)
				# The index will be rebuilt automatically on next access via to_h
				headers.policy = Protocol::GRPC::HEADER_POLICY unless headers.policy == Protocol::GRPC::HEADER_POLICY
				
				status = headers["grpc-status"]
				return Status::UNKNOWN unless status
				
				return status.to_i
			end
			
			# Extract gRPC status message from headers.
			# Returns `Nil` if message is not present.
			#
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [String | Nil] Status message
			def self.extract_message(headers)
				# Ensure policy is set - setting policy clears the index (@indexed = nil)
				# The index will be rebuilt automatically on next access via to_h
				headers.policy = Protocol::GRPC::HEADER_POLICY unless headers.policy == Protocol::GRPC::HEADER_POLICY
				
				message = headers["grpc-message"]
				return nil unless message
				
				return message.decode
			end
			
			# Assign gRPC status, message, and optional backtrace to headers.
			#
			# Whether these become headers or trailers is controlled by the protocol layer.
			#
			# @parameter headers [Protocol::HTTP::Headers]
			# @parameter status [Integer] gRPC status code
			# @parameter message [String | Nil] Optional status message
			# @parameter error [Exception | Nil] Optional error object (used to extract backtrace)
			def self.assign_status!(headers, status: Status::OK, message: nil, error: nil)
				headers["grpc-status"] = status
				
				if error && message.nil?
					# If message is not provided but error is, use error message
					message = error.message
				end
				
				if message
					headers["grpc-message"] = message
				end
				
				# Add backtrace from error if available
				if error && error.backtrace && !error.backtrace.empty?
					# Assign backtrace array directly - Split header will handle it
					headers["backtrace"] = error.backtrace
				end
				
				return headers
			end
			
			class << self
				# Backward compatibility alias
				alias add_status! assign_status!
			end
		end
	end
end
