# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module GRPC
		# @namespace
		module HealthCheck
			# Health check status constants
			module ServingStatus
				UNKNOWN = 0
				SERVING = 1
				NOT_SERVING = 2
				SERVICE_UNKNOWN = 3
			end
		end
	end
end
