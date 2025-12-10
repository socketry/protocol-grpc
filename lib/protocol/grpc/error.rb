# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module GRPC
		# Base exception class for gRPC errors
		class Error < StandardError
			attr_reader :status_code, :details, :metadata
			
			# @parameter status_code [Integer] gRPC status code
			# @parameter message [String, nil] Error message
			# @parameter details [Object, nil] Error details
			# @parameter metadata [Hash] Custom metadata
			def initialize(status_code, message = nil, details: nil, metadata: {})
				@status_code = status_code
				@details = details
				@metadata = metadata
				super(message || Status::DESCRIPTIONS[status_code])
			end
			
			# Map status code to error class
			# @parameter status_code [Integer] gRPC status code
			# @returns [Class] Error class for the status code
			def self.error_class_for_status(status_code)
				case status_code
				when Status::CANCELLED then Cancelled
				when Status::INVALID_ARGUMENT then InvalidArgument
				when Status::DEADLINE_EXCEEDED then DeadlineExceeded
				when Status::NOT_FOUND then NotFound
				when Status::INTERNAL then Internal
				when Status::UNAVAILABLE then Unavailable
				when Status::UNAUTHENTICATED then Unauthenticated
				else
					Error
				end
			end
			
			# Create an appropriate error instance for the given status code
			# @parameter status_code [Integer] gRPC status code
			# @parameter message [String, nil] Error message
			# @parameter metadata [Hash] Custom metadata
			# @returns [Error] An instance of the appropriate error class
			def self.for(status_code, message = nil, metadata: {})
				error_class = error_class_for_status(status_code)
				
				if error_class == Error
					error_class.new(status_code, message, metadata: metadata)
				else
					error_class.new(message, metadata: metadata)
				end
			end
		end
		
		# Specific error classes for common status codes
		class Cancelled < Error
			def initialize(message = nil, **options)
				super(Status::CANCELLED, message, **options)
			end
		end
		
		class InvalidArgument < Error
			def initialize(message = nil, **options)
				super(Status::INVALID_ARGUMENT, message, **options)
			end
		end
		
		class DeadlineExceeded < Error
			def initialize(message = nil, **options)
				super(Status::DEADLINE_EXCEEDED, message, **options)
			end
		end
		
		class NotFound < Error
			def initialize(message = nil, **options)
				super(Status::NOT_FOUND, message, **options)
			end
		end
		
		class Internal < Error
			def initialize(message = nil, **options)
				super(Status::INTERNAL, message, **options)
			end
		end
		
		class Unavailable < Error
			def initialize(message = nil, **options)
				super(Status::UNAVAILABLE, message, **options)
			end
		end
		
		class Unauthenticated < Error
			def initialize(message = nil, **options)
				super(Status::UNAUTHENTICATED, message, **options)
			end
		end
	end
end
