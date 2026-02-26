# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/http"

require_relative "status"
require_relative "header/status"
require_relative "header/message"
require_relative "header/timeout"
require_relative "header/encoding"

module Protocol
	module GRPC
		# @namespace
		module Header
		end
		
		# Custom header policy for gRPC.
		# Extends Protocol::HTTP::Headers::POLICY with gRPC-specific headers.
		HEADER_POLICY = Protocol::HTTP::Headers::POLICY.merge(
			# Request headers:
			"grpc-timeout" => Header::Timeout,
			"grpc-encoding" => Header::Encoding,
			
			# Response headers:
			"grpc-status" => Header::Status,
			"grpc-message" => Header::Message
			# By default, all other headers follow standard HTTP policy, but gRPC allows most metadata to be sent as trailers.
		).freeze
	end
end
