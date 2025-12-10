# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http"
require "protocol/http/body/writable"
require "zlib"
require "stringio"

module Protocol
	module GRPC
		module Body
			# Writes length-prefixed gRPC messages
			# This is the standard writable body for gRPC - all gRPC requests use message framing
			class WritableBody < Protocol::HTTP::Body::Writable
				# @parameter encoding [String, nil] Compression encoding (gzip, deflate, identity)
				# @parameter level [Integer] Compression level if encoding is used
				# @parameter message_class [Class, nil] Expected message class for validation
				def initialize(encoding: nil, level: Zlib::DEFAULT_COMPRESSION, message_class: nil, **options)
					super(**options)
					@encoding = encoding
					@level = level
					@message_class = message_class
				end
				
				attr_reader :encoding
				attr_reader :message_class
				
				# Write a message with gRPC framing
				# @parameter message [Object, String] Protobuf message instance or raw binary data
				# @parameter compressed [Boolean] Whether to compress this specific message
				def write(message, compressed: nil)
					# Validate message type if message_class is specified
					if @message_class && !message.is_a?(String)
						unless message.is_a?(@message_class)
							raise TypeError, "Expected #{@message_class}, got #{message.class}"
						end
					end
					# Encode message to binary if it's not already a string
					# This supports both high-level (protobuf objects) and low-level (binary) usage
					data = if message.is_a?(String)
						message # Already binary, use as-is (for channel adapters)
					elsif message.respond_to?(:to_proto)
						# Use protobuf gem's to_proto or encode method
						message.to_proto
					elsif message.respond_to?(:encode)
						message.encode
					else
						raise ArgumentError, "Message must respond to :to_proto or :encode"
					end
					
					# Determine if we should compress this message
					# If compressed param is nil, use the encoding setting
					should_compress = compressed.nil? ? (@encoding && @encoding != "identity") : compressed
					
					# Compress if requested
					data = compress(data) if should_compress
					
					# Build prefix: compression flag + length
					compression_flag = should_compress ? 1 : 0
					length = data.bytesize
					prefix = [compression_flag].pack("C") + [length].pack("N")
					
					# Write prefix + data to underlying body
					super(prefix + data) # Call Protocol::HTTP::Body::Writable#write
				end
				
					protected
				
				def compress(data)
					case @encoding
					when "gzip"
						io = StringIO.new
						gz = Zlib::GzipWriter.new(io, @level)
						gz.write(data)
						gz.close
						io.string
					when "deflate"
						Zlib::Deflate.deflate(data, @level)
					else
						data # No compression or identity
					end
				rescue StandardError => error
					raise Error.new(Status::INTERNAL, "Failed to compress message: #{error.message}")
				end
			end
		end
	end
end
