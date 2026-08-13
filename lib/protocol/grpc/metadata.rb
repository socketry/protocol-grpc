# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "header"
require_relative "status"

module Protocol
	module GRPC
		# @namespace
		module Metadata
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
