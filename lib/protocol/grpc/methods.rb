# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "metadata"
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
			# @deprecated Use {Metadata.build} instead.
			def self.build_headers(metadata: {}, timeout: nil, content_type: "application/grpc+proto")
				Kernel.warn("`Protocol::GRPC::Methods.build_headers` is deprecated; use `Protocol::GRPC::Metadata.build` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
				
				Metadata.build(metadata: metadata, timeout: timeout, content_type: content_type)
			end
			
			# Extract metadata from gRPC headers.
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Hash] Metadata key-value pairs
			# @deprecated Use {Metadata.extract} instead.
			def self.extract_metadata(headers)
				Kernel.warn("`Protocol::GRPC::Methods.extract_metadata` is deprecated; use `Protocol::GRPC::Metadata.extract` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
				
				Metadata.extract(headers)
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
