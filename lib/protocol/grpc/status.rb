# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module GRPC
		# gRPC status codes
		module Status
			OK = 0
			CANCELLED = 1
			UNKNOWN = 2
			INVALID_ARGUMENT = 3
			DEADLINE_EXCEEDED = 4
			NOT_FOUND = 5
			ALREADY_EXISTS = 6
			PERMISSION_DENIED = 7
			RESOURCE_EXHAUSTED = 8
			FAILED_PRECONDITION = 9
			ABORTED = 10
			OUT_OF_RANGE = 11
			UNIMPLEMENTED = 12
			INTERNAL = 13
			UNAVAILABLE = 14
			DATA_LOSS = 15
			UNAUTHENTICATED = 16
			
			# Status code descriptions
			DESCRIPTIONS = {
				OK => "OK",
				CANCELLED => "Cancelled",
				UNKNOWN => "Unknown",
				INVALID_ARGUMENT => "Invalid Argument",
				DEADLINE_EXCEEDED => "Deadline Exceeded",
				NOT_FOUND => "Not Found",
				ALREADY_EXISTS => "Already Exists",
				PERMISSION_DENIED => "Permission Denied",
				RESOURCE_EXHAUSTED => "Resource Exhausted",
				FAILED_PRECONDITION => "Failed Precondition",
				ABORTED => "Aborted",
				OUT_OF_RANGE => "Out of Range",
				UNIMPLEMENTED => "Unimplemented",
				INTERNAL => "Internal",
				UNAVAILABLE => "Unavailable",
				DATA_LOSS => "Data Loss",
				UNAUTHENTICATED => "Unauthenticated"
			}.freeze
		end
	end
end
