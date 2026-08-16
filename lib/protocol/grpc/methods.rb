# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "base64"
require "protocol/http"

require_relative "header/timeout"
require_relative "route"

module Protocol
	module GRPC
		# Provides utility methods for building and parsing gRPC-compatible HTTP requests.
		module Methods
			# Build gRPC path from service and method.
			# @parameter service [String] e.g., "my_service.Greeter"
			# @parameter method [String] e.g., "SayHello"
			# @returns [String] e.g., "/my_service.Greeter/SayHello"
			# @deprecated Use {Route.build} instead.
			def self.build_path(service, method)
				Kernel.warn("`Protocol::GRPC::Methods.build_path` is deprecated; use `Protocol::GRPC::Route.build` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
				
				Route.build(service, method)
			end
			
			# Parse service and method from gRPC path.
			# @parameter path [String] e.g., "/my_service.Greeter/SayHello"
			# @returns [Array(String | String)] [service, method]
			# @deprecated Use {Route.parse} instead.
			def self.parse_path(path)
				Kernel.warn("`Protocol::GRPC::Methods.parse_path` is deprecated; use `Protocol::GRPC::Route.parse` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
				
				Route.parse(path)
			end
			
			# Build gRPC request headers.
			# @parameter metadata [Hash] Custom metadata key-value pairs
			# @parameter timeout [Numeric | Nil] Optional timeout in seconds
			# @parameter content_type [String] Content type (default: "application/grpc+proto")
			# @returns [Protocol::HTTP::Headers]
			def self.build_headers(metadata: {}, timeout: nil, content_type: "application/grpc+proto")
				headers = Protocol::HTTP::Headers.new(policy: Protocol::GRPC::HEADER_POLICY)
				headers["content-type"] = content_type
				headers["te"] = "trailers"
				
				if timeout
					# Coerced to proper format by header policy:
					headers["grpc-timeout"] = timeout
				end
				
				metadata.each do |key, value|
					# Binary headers end with -bin and are base64 encoded:
					headers[key] = if key.end_with?("-bin")
						Base64.strict_encode64(value)
					else
						value.to_s
					end
				end
				
				headers
			end
			
			# Extract metadata from gRPC headers.
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Hash] Metadata key-value pairs
			def self.extract_metadata(headers)
				metadata = {}
				
				headers.to_h.each do |key, value|
					# Skip reserved headers:
					next if key.start_with?("grpc-") || key == "content-type" || key == "te"
					
					# Decode binary headers:
					if key.end_with?("-bin")
						if value.is_a?(String)
							value = Base64.strict_decode64(value)
						elsif value.is_a?(Array)
							value = value.map{|item| Base64.strict_decode64(item)}
						end
					else
						value
					end
					
					metadata[key] = value
				end
				
				metadata
			end
			
			# Format timeout for grpc-timeout header.
			# @parameter timeout [Numeric] Timeout in seconds
			# @returns [String] e.g., "1000m" for 1 second
			# @deprecated Use {Protocol::GRPC::Header::Timeout.format} instead.
			def self.format_timeout(timeout)
				Kernel.warn("`Protocol::GRPC::Methods.format_timeout` is deprecated; use `Protocol::GRPC::Header::Timeout.format` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
				
				Header::Timeout.format(timeout)
			end
			
			# Parse grpc-timeout header value.
			# @parameter value [String] e.g., "1000m"
			# @returns [Numeric | Nil] Timeout in seconds, or `Nil` if value is invalid
			# @deprecated Use {Protocol::GRPC::Header::Timeout#to_seconds} instead.
			def self.parse_timeout(value)
				Kernel.warn("`Protocol::GRPC::Methods.parse_timeout` is deprecated; use `Protocol::GRPC::Header::Timeout#to_seconds` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
				
				return nil unless value
				
				Header::Timeout.parse(value).to_seconds
			rescue ArgumentError
				return nil
			end
		end
	end
end
