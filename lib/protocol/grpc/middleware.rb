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
					trailers_only_error(error.status_code, error.message)
				rescue StandardError => error
					trailers_only_error(Status::INTERNAL, error.message)
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
			
			# Build a trailers-only error response.
			# @parameter status_code [Integer] gRPC status code
			# @parameter message [String] Error message
			# @returns [Protocol::HTTP::Response]
			def trailers_only_error(status_code, message)
				Metadata.build_trailers_only_response(
					status: status_code,
					message: message,
					policy: HEADER_POLICY
				)
			end
		end
	end
end
