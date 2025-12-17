# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http"
require "protocol/http/body/writable"
require "zlib"
require "stringio"

module Protocol
	module GRPC
		# @namespace
		module Body
			# Represents a writable body for gRPC messages with length-prefixed framing.
			# This is the standard writable body for gRPC - all gRPC requests use message framing.
			class Writable < Protocol::HTTP::Body::Writable
				# Initialize a new writable body for gRPC messages.
				# @parameter encoding [String | Nil] Compression encoding (gzip, deflate, identity)
				# @parameter level [Integer] Compression level if encoding is used
				# @parameter message_class [Class | Nil] Expected message class for validation
				def initialize(encoding: nil, level: Zlib::DEFAULT_COMPRESSION, message_class: nil, **options)
					super(**options)
					@encoding = encoding
					@level = level
					@message_class = message_class
				end
				
				# @attribute [String | Nil] The compression encoding.
				attr_reader :encoding
				
				# @attribute [Class | Nil] The expected message class for validation.
				attr_reader :message_class
				
				# Write a message with gRPC framing.
				# @parameter message [Object, String] Protobuf message instance or raw binary data
				# @parameter compressed [Boolean | Nil] Whether to compress this specific message. If `nil`, uses the encoding setting.
				def write(message, compressed: nil)
					# Validate message type if message_class is specified:
					if @message_class && !message.is_a?(String)
						unless message.is_a?(@message_class)
							raise TypeError, "Expected #{@message_class}, got #{message.class}"
						end
					end
					
					# Encode message to binary if it's not already a string:
					# This supports both high-level (protobuf objects) and low-level (binary) usage
					data = if message.is_a?(String)
						message # Already binary, use as-is (for channel adapters)
					elsif message.respond_to?(:to_proto)
						# Use protobuf gem's to_proto method:
						message.to_proto
					elsif message.respond_to?(:encode)
						# Use encode method:
						message.encode
					else
						raise ArgumentError, "Message must respond to :to_proto or :encode"
					end
					
					# Determine if we should compress this message:
					# If compressed param is nil, use the encoding setting
					should_compress = compressed.nil? ? (@encoding && @encoding != "identity") : compressed
					
					# Compress if requested:
					data = compress(data) if should_compress
					
					# Build prefix: compression flag + length
					compression_flag = should_compress ? 1 : 0
					length = data.bytesize
					prefix = [compression_flag].pack("C") + [length].pack("N")
					
					# Write prefix + data to underlying body:
					super(prefix + data) # Call Protocol::HTTP::Body::Writable#write
				end
				
				protected
				
				# Compress data using the configured encoding.
				# @parameter data [String] The data to compress
				# @returns [String] The compressed data
				# @raises [Error] If compression fails
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
