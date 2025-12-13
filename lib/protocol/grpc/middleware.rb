# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http"
require_relative "error"
require_relative "status"
require_relative "metadata"
require_relative "header"

module Protocol
	module GRPC
		# Represents server middleware for handling gRPC requests.
		# Implements Protocol::HTTP::Middleware interface.
		# Subclasses should implement {dispatch} to handle service routing and protocol details.
		class Middleware < Protocol::HTTP::Middleware
			# Initialize a new middleware instance.
			# @parameter app [#call | Nil] The next middleware in the chain
			def initialize(app = nil)
				super(app)
			end
			
			# Handle incoming HTTP request.
			# @parameter request [Protocol::HTTP::Request]
			# @returns [Protocol::HTTP::Response]
			def call(request)
				return super unless grpc_request?(request)
				
				begin
					dispatch(request)
				rescue Error => error
					make_response(error.status_code, error.message, error: error)
				rescue StandardError => error
					make_response(Status::INTERNAL, error.message, error: error)
				end
			end
			
			# Dispatch the request to the service handler.
			# Subclasses should implement this method to handle routing and protocol details.
			# @parameter request [Protocol::HTTP::Request]
			# @returns [Protocol::HTTP::Response]
			# @raises [NotImplementedError] If not implemented by subclass
			def dispatch(request)
				raise NotImplementedError, "Subclasses must implement #dispatch"
			end
			
		protected
			
			# Check if the request is a gRPC request.
			# @parameter request [Protocol::HTTP::Request]
			# @returns [Boolean] `true` if the request is a gRPC request, `false` otherwise
			def grpc_request?(request)
				content_type = request.headers["content-type"]
				content_type&.start_with?("application/grpc")
			end
			
			# Make a gRPC error response with status and optional message.
			# @parameter status_code [Integer] gRPC status code
			# @parameter message [String] Error message
			# @parameter error [Exception] Optional error object (used to extract backtrace)
			# @returns [Protocol::HTTP::Response]
			def make_response(status_code, message, error: nil)
				headers = Protocol::HTTP::Headers.new([], nil, policy: HEADER_POLICY)
				headers["content-type"] = "application/grpc+proto"
				Metadata.add_status!(headers, status: status_code, message: message, error: error)
				
				Protocol::HTTP::Response[200, headers, nil]
			end
		end
	end
end
