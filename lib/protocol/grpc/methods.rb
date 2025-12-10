# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "base64"
require "protocol/http"

module Protocol
	module GRPC
		# Helper module for building gRPC-compatible HTTP requests
		module Methods
			# Build gRPC path from service and method
			# @parameter service [String] e.g., "my_service.Greeter"
			# @parameter method [String] e.g., "SayHello"
			# @returns [String] e.g., "/my_service.Greeter/SayHello"
			def self.build_path(service, method)
				"/#{service}/#{method}"
			end
			
			# Parse service and method from gRPC path
			# @parameter path [String] e.g., "/my_service.Greeter/SayHello"
			# @returns [Array(String, String)] [service, method]
			def self.parse_path(path)
				parts = path.split("/")
				[parts[1], parts[2]]
			end
			
			# Build gRPC request headers
			# @parameter metadata [Hash] Custom metadata key-value pairs
			# @parameter timeout [Numeric] Optional timeout in seconds
			# @parameter content_type [String] Content type (default: "application/grpc+proto")
			# @returns [Protocol::HTTP::Headers]
			def self.build_headers(metadata: {}, timeout: nil, content_type: "application/grpc+proto")
				headers = Protocol::HTTP::Headers.new
				headers["content-type"] = content_type
				headers["te"] = "trailers"
				headers["grpc-timeout"] = format_timeout(timeout) if timeout
				
				metadata.each do |key, value|
					# Binary headers end with -bin and are base64 encoded
					headers[key] = if key.end_with?("-bin")
						Base64.strict_encode64(value)
					else
						value.to_s
					end
				end
				
				headers
			end
			
			# Extract metadata from gRPC headers
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Hash] Metadata key-value pairs
			def self.extract_metadata(headers)
				metadata = {}
				
				headers.each do |key, value|
					# Skip reserved headers
					next if key.start_with?("grpc-") || key == "content-type" || key == "te"
					
					# Decode binary headers
					metadata[key] = if key.end_with?("-bin")
						Base64.strict_decode64(value)
					else
						value
					end
				end
				
				metadata
			end
			
			# Format timeout for grpc-timeout header
			# @parameter timeout [Numeric] Timeout in seconds
			# @returns [String] e.g., "1000m" for 1 second
			def self.format_timeout(timeout)
				# gRPC timeout format: value + unit (H=hours, M=minutes, S=seconds, m=milliseconds, u=microseconds, n=nanoseconds)
				if timeout >= 3600
					"#{(timeout / 3600).to_i}H"
				elsif timeout >= 60
					"#{(timeout / 60).to_i}M"
				elsif timeout >= 1
					"#{timeout.to_i}S"
				elsif timeout >= 0.001
					"#{(timeout * 1000).to_i}m"
				elsif timeout >= 0.000001
					"#{(timeout * 1_000_000).to_i}u"
				else
					"#{(timeout * 1_000_000_000).to_i}n"
				end
			end
			
			# Parse grpc-timeout header value
			# @parameter value [String] e.g., "1000m"
			# @returns [Numeric] Timeout in seconds
			def self.parse_timeout(value)
				return nil unless value
				
				amount = value[0...-1].to_i
				unit = value[-1]
				
				case unit
				when "H" then amount * 3600
				when "M" then amount * 60
				when "S" then amount
				when "m" then amount / 1000.0
				when "u" then amount / 1_000_000.0
				when "n" then amount / 1_000_000_000.0
				end
			end
		end
	end
end
