# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http"

module Protocol
	module GRPC
		module Header
			# Base class for custom gRPC metadata (allowed in trailers).
			class Metadata < Protocol::HTTP::Header::Split
				# Whether this header is acceptable in HTTP trailers.
				# The `grpc-metadata` header can appear in trailers as per the gRPC specification.
				# @returns [Boolean] `true`, as grpc-metadata can appear in trailers.
				def self.trailer?
					true
				end
			end
		end
	end
end
