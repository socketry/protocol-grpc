# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/deadline"
require_relative "metadata"

module Protocol
	module GRPC
		# Represents context for a single RPC call.
		class Call
			# Create a new RPC call context for the given request and response.
			# Automatically computes a deadline from the `grpc-timeout` request header, if present.
			# @parameter request [Protocol::HTTP::Request] The HTTP request
			# @parameter response [Protocol::HTTP::Response | Nil] The HTTP response
			# @returns [Call] The new call context.
			def self.for(request, response = nil)
				if timeout = request.headers["grpc-timeout"]
					deadline = Async::Deadline.start(timeout.to_seconds)
				end
				
				return new(request, response, deadline: deadline)
			end
			
			# Initialize a new RPC call context.
			# @parameter request [Protocol::HTTP::Request] The HTTP request
			# @parameter response [Protocol::HTTP::Response | Nil] The HTTP response (for setting metadata and trailers)
			# @parameter deadline [Async::Deadline | Nil] Deadline for the call
			def initialize(request, response = nil, deadline: nil)
				@request = request
				@response = response
				@deadline = deadline
			end
			
			# @attribute [Protocol::HTTP::Request] The underlying HTTP request.
			attr_reader :request
			
			# @attribute [Protocol::HTTP::Response | Nil] The HTTP response.
			attr_reader :response
			
			# @attribute [Async::Deadline | Nil] The deadline for this call.
			attr_reader :deadline
			
			# Extract metadata from request headers.
			# @returns [Hash] Custom metadata key-value pairs
			def metadata
				@metadata ||= Metadata.extract(@request.headers)
			end
			
			# Get the timeout requested by the client.
			# @returns [Numeric | Nil] The original timeout in seconds, or `nil` if no timeout was specified.
			def timeout
				@request.headers["grpc-timeout"]&.to_seconds
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
			
			# Get peer information (client address).
			# @returns [String | Nil] The peer address as a string, or `Nil` if not available
			def peer
				@request.peer&.to_s
			end
		end
	end
end
