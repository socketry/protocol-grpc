# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/http"

require_relative "status"
require_relative "header/status"
require_relative "header/message"

module Protocol
	module GRPC
		# @namespace
		module Header
		end
		
		# Custom header policy for gRPC.
		# Extends Protocol::HTTP::Headers::POLICY with gRPC-specific headers.
		HEADER_POLICY = Protocol::HTTP::Headers::POLICY.merge(
			"grpc-status" => Header::Status,
			"grpc-message" => Header::Message
			# By default, all other headers follow standard HTTP policy, but gRPC allows most metadata to be sent as trailers.
		).freeze
	end
end
