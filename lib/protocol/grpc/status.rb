# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module GRPC
		# Provides gRPC status codes and their names.
		module Status
			# Map an HTTP response status when the server did not provide grpc-status.
			# @parameter status [Integer] The HTTP status code.
			# @returns [Integer] The fallback gRPC status code.
			def self.for_http_status(status)
				case status
				when 400 then INTERNAL
				when 401 then UNAUTHENTICATED
				when 403 then PERMISSION_DENIED
				when 404 then UNIMPLEMENTED
				when 429, 502, 503, 504 then UNAVAILABLE
				else UNKNOWN
				end
			end
			
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
			
			# Status code names, as defined by the gRPC specification.
			NAMES = {
				OK => "OK",
				CANCELLED => "CANCELLED",
				UNKNOWN => "UNKNOWN",
				INVALID_ARGUMENT => "INVALID_ARGUMENT",
				DEADLINE_EXCEEDED => "DEADLINE_EXCEEDED",
				NOT_FOUND => "NOT_FOUND",
				ALREADY_EXISTS => "ALREADY_EXISTS",
				PERMISSION_DENIED => "PERMISSION_DENIED",
				RESOURCE_EXHAUSTED => "RESOURCE_EXHAUSTED",
				FAILED_PRECONDITION => "FAILED_PRECONDITION",
				ABORTED => "ABORTED",
				OUT_OF_RANGE => "OUT_OF_RANGE",
				UNIMPLEMENTED => "UNIMPLEMENTED",
				INTERNAL => "INTERNAL",
				UNAVAILABLE => "UNAVAILABLE",
				DATA_LOSS => "DATA_LOSS",
				UNAUTHENTICATED => "UNAUTHENTICATED"
			}.freeze
		end
	end
end
