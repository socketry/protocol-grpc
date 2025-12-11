# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module GRPC
		module Proto
			# Parser for Protocol Buffers `.proto` files.
			# Extracts service definitions, RPC methods, and package information.
			class Parser
				# Initialize the parser with a proto file path.
				# @parameter proto_file [String] Path to the `.proto` file
				def initialize(proto_file)
					@proto_file = proto_file
					@content = File.read(proto_file)
				end
				
				# Parse the proto file and return structured data.
				# @returns [Hash] Parsed data with `:package` and `:services` keys
				def parse
					package = extract_package
					services = extract_services
					
					{
						package: package,
						services: services
					}
				end
				
				# Get the package name.
				# @returns [String | Nil] The package name
				def package
					extract_package
				end
				
				# Get all service names found in the proto file.
				# @returns [Array<String>] List of service names
				def service_names
					extract_services.map{|s| s[:name]}
				end
				
			private
				
				def extract_package
					@content[/package\s+([\w.]+)\s*;/, 1]
				end
				
				def extract_services
					services = []
					
					@content.scan(/service\s+(\w+)\s*\{([^}]+)\}/m) do |service_name, service_body|
						rpcs = []
						
						service_body.scan(/rpc\s+(\w+)\s*\(([^)]+)\)\s+returns\s*\(([^)]+)\)\s*;/) do |rpc_name, request, response|
							request = request.strip
							response = response.strip
							
							# Determine streaming type
							request_streaming = request.start_with?("stream ")
							response_streaming = response.start_with?("stream ")
							
							request_type = request.sub(/^stream\s+/, "")
							response_type = response.sub(/^stream\s+/, "")
							
							streaming = if request_streaming && response_streaming
								:bidirectional
							elsif response_streaming
								:server_streaming
							elsif request_streaming
								:client_streaming
							else
								:unary
							end
							
							rpcs << {
								name: rpc_name,
								request: request_type,
								response: response_type,
								streaming: streaming
							}
						end
						
						services << {
							name: service_name,
							rpcs: rpcs
						}
					end
					
					services
				end
			end
		end
	end
end
