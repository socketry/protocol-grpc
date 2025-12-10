# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "uri"
require_relative "header"
require_relative "status"

module Protocol
	module GRPC
		module Metadata
			# Extract gRPC status from headers.
			# Convenience method that handles both Header::Status instances and raw values.
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
				
				if status.is_a?(Header::Status)
					status.to_i
				else
					# Fallback for when header policy isn't used
					status_value = status.is_a?(Array) ? status.first : status.to_s
					status_value.to_i
				end
			end
			
			# Extract gRPC status message from headers.
			# Convenience method that handles both Header::Message instances and raw values.
			# Returns nil if message is not present.
			#
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [String, nil] Status message
			def self.extract_message(headers)
				# Ensure policy is set - setting policy clears the index (@indexed = nil)
				# The index will be rebuilt automatically on next access via to_h
				headers.policy = Protocol::GRPC::HEADER_POLICY unless headers.policy == Protocol::GRPC::HEADER_POLICY
				
				message = headers["grpc-message"]
				return nil unless message
				
				if message.is_a?(Header::Message)
					message.decode
				else
					# Fallback for when header policy isn't used
					message_value = message.is_a?(Array) ? message.first : message.to_s
					URI.decode_www_form_component(message_value)
				end
			end
			
			# Build headers with gRPC status and message
			# @parameter status [Integer] gRPC status code
			# @parameter message [String, nil] Optional status message
			# @parameter policy [Hash] Header policy to use
			# @returns [Protocol::HTTP::Headers]
			def self.build_status_headers(status: Status::OK, message: nil, policy: HEADER_POLICY)
				headers = Protocol::HTTP::Headers.new([], nil, policy: policy)
				headers["grpc-status"] = Header::Status.new(status)
				headers["grpc-message"] = Header::Message.new(Header::Message.encode(message)) if message
				headers
			end
			
			# Mark that trailers will follow (call after sending initial headers)
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Protocol::HTTP::Headers]
			def self.prepare_trailers!(headers)
				headers.trailer!
				headers
			end
			
			# Add status as trailers to existing headers
			# @parameter headers [Protocol::HTTP::Headers]
			# @parameter status [Integer] gRPC status code
			# @parameter message [String, nil] Optional status message
			def self.add_status_trailer!(headers, status: Status::OK, message: nil)
				headers.trailer! unless headers.trailer?
				headers["grpc-status"] = Header::Status.new(status)
				headers["grpc-message"] = Header::Message.new(Header::Message.encode(message)) if message
			end
			
			# Add status as initial headers (for trailers-only responses)
			# @parameter headers [Protocol::HTTP::Headers]
			# @parameter status [Integer] gRPC status code
			# @parameter message [String, nil] Optional status message
			def self.add_status_header!(headers, status: Status::OK, message: nil)
				headers["grpc-status"] = Header::Status.new(status)
				headers["grpc-message"] = Header::Message.new(Header::Message.encode(message)) if message
			end
			
			# Build a trailers-only error response (no body, status in headers)
			# @parameter status [Integer] gRPC status code
			# @parameter message [String, nil] Optional status message
			# @parameter policy [Hash] Header policy to use
			# @returns [Protocol::HTTP::Response]
			def self.build_trailers_only_response(status:, message: nil, policy: HEADER_POLICY)
				headers = Protocol::HTTP::Headers.new([], nil, policy: policy)
				headers["content-type"] = "application/grpc+proto"
				add_status_header!(headers, status: status, message: message)
				
				Protocol::HTTP::Response[200, headers, nil]
			end
		end
	end
end
