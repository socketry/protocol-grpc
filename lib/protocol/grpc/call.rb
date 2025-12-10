# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/deadline"
require_relative "methods"

module Protocol
	module GRPC
		# Represents context for a single RPC call
		class Call
			# @parameter request [Protocol::HTTP::Request] The HTTP request
			# @parameter deadline [Async::Deadline, nil] Deadline for the call
			def initialize(request, deadline: nil)
				@request = request
				@deadline = deadline
				@cancelled = false
			end
			
			# @attribute [Protocol::HTTP::Request] The underlying HTTP request
			attr_reader :request
			
			# @attribute [Async::Deadline, nil] The deadline for this call
			attr_reader :deadline
			
			# Extract metadata from request headers
			# @returns [Hash] Custom metadata
			def metadata
				@metadata ||= Methods.extract_metadata(@request.headers)
			end
			
			# Check if the deadline has expired
			# @returns [Boolean]
			def deadline_exceeded?
				@deadline&.expired? || false
			end
			
			# Time remaining until deadline
			# @returns [Numeric, nil] Seconds remaining, or nil if no deadline
			def time_remaining
				@deadline&.remaining
			end
			
			# Mark this call as cancelled
			def cancel!
				@cancelled = true
			end
			
			# Check if call was cancelled
			# @returns [Boolean]
			def cancelled?
				@cancelled
			end
			
			# Get peer information (client address)
			# @returns [String, nil]
			def peer
				@request.peer&.to_s
			end
		end
	end
end
