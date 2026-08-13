# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module GRPC
		# Provides operations for parsing and building gRPC request paths.
		module Route
			IDENTIFIER_PATTERN = "[A-Za-z][A-Za-z0-9_]*"
			SERVICE_PATTERN = /\A#{IDENTIFIER_PATTERN}(?:\.#{IDENTIFIER_PATTERN})*\z/
			METHOD_PATTERN = /\A#{IDENTIFIER_PATTERN}\z/
			PATTERN = %r{\A/(#{IDENTIFIER_PATTERN}(?:\.#{IDENTIFIER_PATTERN})*)/(#{IDENTIFIER_PATTERN})\z}
			private_constant :IDENTIFIER_PATTERN, :SERVICE_PATTERN, :METHOD_PATTERN, :PATTERN
			
			# Parse a gRPC request path into its service and method names.
			# @parameter path [String] The gRPC request path.
			# @returns [Array(String)] The service and method names.
			# @raises [ArgumentError] If the path does not contain valid protobuf service and method names.
			def self.parse(path)
				match = PATTERN.match(path) if path.is_a?(String)
				
				unless match
					raise ArgumentError, "Invalid gRPC route: #{path.inspect}"
				end
				
				[match[1], match[2]]
			end
			
			# Build a gRPC request path from its service and method names.
			# @parameter service_name [String] The fully qualified service name.
			# @parameter method_name [String] The method name.
			# @returns [String] The gRPC request path.
			# @raises [ArgumentError] If either component is not a valid protobuf service or method name.
			def self.build(service_name, method_name)
				unless service_name.is_a?(String) && SERVICE_PATTERN.match?(service_name)
					raise ArgumentError, "Invalid gRPC service name: #{service_name.inspect}"
				end
				
				unless method_name.is_a?(String) && METHOD_PATTERN.match?(method_name)
					raise ArgumentError, "Invalid gRPC method name: #{method_name.inspect}"
				end
				
				"/#{service_name}/#{method_name}"
			end
		end
	end
end
