# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/deadline"
require_relative "methods"

module Protocol
	module GRPC
		# Represents context for a single RPC call.
		class Call
			# Initialize a new RPC call context.
			# @parameter request [Protocol::HTTP::Request] The HTTP request
			# @parameter deadline [Async::Deadline | Nil] Deadline for the call
			def initialize(request, deadline: nil)
				@request = request
				@deadline = deadline
				@cancelled = false
			end
			
			# @attribute [Protocol::HTTP::Request] The underlying HTTP request.
			attr_reader :request
			
			# @attribute [Async::Deadline | Nil] The deadline for this call.
			attr_reader :deadline
			
			# Extract metadata from request headers.
			# @returns [Hash] Custom metadata key-value pairs
			def metadata
				@metadata ||= Methods.extract_metadata(@request.headers)
			end
			
			# Check if the deadline has expired.
			# @returns [Boolean] `true` if the deadline has expired, `false` otherwise
			def deadline_exceeded?
				@deadline&.expired? || false
			end
			
			# Get the time remaining until the deadline.
			# @returns [Numeric | Nil] Seconds remaining, or `Nil` if no deadline is set
			def time_remaining
				@deadline&.remaining
			end
			
			# Mark this call as cancelled.
			def cancel!
				@cancelled = true
			end
			
			# Check if the call was cancelled.
			# @returns [Boolean] `true` if the call was cancelled, `false` otherwise
			def cancelled?
				@cancelled
			end
			
			# Get peer information (client address).
			# @returns [String | Nil] The peer address as a string, or `Nil` if not available
			def peer
				@request.peer&.to_s
			end
		end
	end
end
