# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/interface"
require_relative "parser"

module Protocol
	module GRPC
		module Proto
			# Generator for Protocol Buffers service definitions.
			# Generates `Protocol::GRPC::Interface` and `Async::GRPC::Service` classes from parsed proto data.
			class Generator
				# Initialize the generator with parsed proto data.
				# @parameter proto_file [String] Path to the original `.proto` file (for header comments)
				# @parameter parsed_data [Hash] Parsed data from `Parser#parse` with `:package` and `:services` keys
				def initialize(proto_file, parsed_data)
					@proto_file = proto_file
					@package = parsed_data[:package]
					@services = parsed_data[:services]
				end
				
				# Generate the interface class code.
				# @parameter service_name [String] The service name
				# @parameter output_path [String | Nil] Optional path to write the file
				# @returns [String] The generated Ruby code
				def generate_interface(service_name, output_path: nil)
					service = @services.find{|s| s[:name] == service_name}
					raise ArgumentError, "Service #{service_name} not found" unless service
					
					package_module = normalize_package_name(@package)
					package_prefix = package_module.empty? ? "" : "#{package_module}::"
					
					code = <<~RUBY
						# frozen_string_literal: true
						
						# Generated from #{File.basename(@proto_file)}
						# DO NOT EDIT - This file is auto-generated
						
						require "protocol/grpc/interface"
						require_relative "#{File.basename(@proto_file, '.proto')}_pb"
						
						#{package_module.empty? ? '' : "module #{package_module}"}
							# Interface definition for the #{service_name} service
							class #{service_name}Interface < Protocol::GRPC::Interface
						#{service[:rpcs].map do |rpc|
							streaming_type = case rpc[:streaming]
							when :unary then ":unary"
							when :server_streaming then ":server_streaming"
							when :client_streaming then ":client_streaming"
							when :bidirectional then ":bidirectional"
							end
							
							"\t\trpc :#{rpc[:name]}, request_class: #{package_prefix}#{rpc[:request]}, response_class: #{package_prefix}#{rpc[:response]}, streaming: #{streaming_type}"
						end.join("\n")}
							end
						#{package_module.empty? ? '' : "end"}
					RUBY
					
					if output_path
						File.write(output_path, code)
					end
					
					code
				end
				
				# Generate the service class code with empty implementations.
				# @parameter service_name [String] The service name
				# @parameter output_path [String | Nil] Optional path to write the file
				# @returns [String] The generated Ruby code
				def generate_service(service_name, output_path: nil)
					service = @services.find{|s| s[:name] == service_name}
					raise ArgumentError, "Service #{service_name} not found" unless service
					
					package_module = normalize_package_name(@package)
					package_prefix = package_module.empty? ? "" : "#{package_module}::"
					interface_class = "#{package_prefix}#{service_name}Interface"
					
					methods = service[:rpcs].map do |rpc|
						method_name = pascal_to_snake(rpc[:name])
						
						case rpc[:streaming]
						when :unary
							<<~RUBY
								def #{method_name}(input, output, _call)
									request = input.read
									# TODO: Implement #{rpc[:name]}
									# response = #{package_prefix}#{rpc[:response]}.new(...)
									# output.write(response)
								end
							RUBY
						when :server_streaming
							<<~RUBY
								def #{method_name}(input, output, _call)
									request = input.read
									# TODO: Implement #{rpc[:name]} streaming
									# response = #{package_prefix}#{rpc[:response]}.new(...)
									# output.write(response)
								end
							RUBY
						when :client_streaming
							<<~RUBY
								def #{method_name}(input, output, _call)
									# TODO: Implement #{rpc[:name]} client streaming
									# input.each do |request|
									#   # Process request
									# end
									# response = #{package_prefix}#{rpc[:response]}.new(...)
									# output.write(response)
								end
							RUBY
						when :bidirectional
							<<~RUBY
								def #{method_name}(input, output, _call)
									# TODO: Implement #{rpc[:name]} bidirectional streaming
									# input.each do |request|
									#   response = #{package_prefix}#{rpc[:response]}.new(...)
									#   output.write(response)
									# end
								end
							RUBY
						end
					end.join("\n")
					
					code = <<~RUBY
						# frozen_string_literal: true
						
						# Generated from #{File.basename(@proto_file)}
						# DO NOT EDIT - This file is auto-generated
						
						require "async/grpc/service"
						require_relative "#{File.basename(@proto_file, '.proto')}_interface"
						
						#{package_module.empty? ? '' : "module #{package_module}"}
							# Service implementation for #{service_name}
							class #{service_name}Service < Async::GRPC::Service
								def initialize(service_name)
									super(#{interface_class}, service_name)
								end
						
						#{methods.split("\n").map{|line| "\t\t#{line}"}.join("\n")}
							end
						#{package_module.empty? ? '' : "end"}
					RUBY
					
					if output_path
						File.write(output_path, code)
					end
					
					code
				end
				
			private
				
				def normalize_package_name(package)
					return "" unless package
					
					package.split(".").map do |part|
						# Convert snake_case to PascalCase
						part.split("_").map(&:capitalize).join
					end.join("::")
				end
				
				def pascal_to_snake(pascal)
					pascal
						.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
						.gsub(/([a-z\d])([A-Z])/, '\1_\2')
						.downcase
				end
			end
		end
	end
end
