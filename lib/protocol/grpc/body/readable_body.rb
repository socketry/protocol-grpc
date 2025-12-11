# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http"
require "protocol/http/body/wrapper"
require "zlib"

module Protocol
	module GRPC
		# @namespace
		module Body
			# Represents a readable body for gRPC messages with length-prefixed framing.
			# This is the standard readable body for gRPC - all gRPC responses use message framing.
			# Wraps the underlying HTTP body and transforms raw chunks into decoded gRPC messages.
			class ReadableBody < Protocol::HTTP::Body::Wrapper
				# Wrap the body of a message.
				#
				# @parameter message [Request | Response] The message to wrap.
				# @parameter options [Hash] The options to pass to the initializer.
				# @returns [ReadableBody | Nil] The wrapped body or `nil` if the message has no body.
				def self.wrap(message, **options)
					if body = message.body
						message.body = self.new(body, **options)
					end
					
					return message.body
				end
				
				# Initialize a new readable body for gRPC messages.
				# @parameter body [Protocol::HTTP::Body::Readable] The underlying HTTP body
				# @parameter message_class [Class | Nil] Protobuf message class with .decode method.
				#   If `nil`, returns raw binary data (useful for channel adapters)
				# @parameter encoding [String | Nil] Compression encoding (from grpc-encoding header)
				def initialize(body, message_class: nil, encoding: nil)
					super(body)
					@message_class = message_class
					@encoding = encoding
					@buffer = String.new.force_encoding(Encoding::BINARY)
				end
				
				# @attribute [String | Nil] The compression encoding.
				attr_reader :encoding
				
				# Read the next gRPC message.
				# Overrides Wrapper#read to transform raw HTTP body chunks into decoded gRPC messages.
				# @returns [Object | String | Nil] Decoded message, raw binary, or `Nil` if stream ended
				def read
					return nil if @body.nil? || @body.empty?
					
					# Read 5-byte prefix: 1 byte compression flag + 4 bytes length
					prefix = read_exactly(5)
					return nil unless prefix
					
					compressed = prefix[0].unpack1("C") == 1
					length = prefix[1..4].unpack1("N")
					
					# Read the message body:
					data = read_exactly(length)
					return nil unless data
					
					# Decompress if needed:
					data = decompress(data) if compressed
					
					# Decode using message class if provided, otherwise return binary:
					# This allows binary mode for channel adapters
					if @message_class
						# Use protobuf gem's decode method:
						@message_class.decode(data)
					else
						data # Return raw binary
					end
				end
				
			private
				
				# Read exactly n bytes from the underlying body.
				# @parameter n [Integer] The number of bytes to read
				# @returns [String | Nil] The data read, or `Nil` if the stream ended
				def read_exactly(n)
					# Fill buffer until we have enough data:
					while @buffer.bytesize < n
						return nil if @body.nil? || @body.empty?
						
						# Read chunk from underlying body:
						chunk = @body.read
						
						if chunk.nil?
							# End of stream:
							return nil
						end
						
						# Append to buffer:
						@buffer << chunk.force_encoding(Encoding::BINARY)
					end
					
					# Extract the required data:
					data = @buffer[0...n]
					@buffer = @buffer[n..]
					data
				end
				
				# Decompress data using the configured encoding.
				# @parameter data [String] The compressed data
				# @returns [String] The decompressed data
				# @raises [Error] If decompression fails
				def decompress(data)
					case @encoding
					when "gzip"
						Zlib::Gunzip.new.inflate(data)
					when "deflate"
						Zlib::Inflate.inflate(data)
					else
						data
					end
				rescue StandardError => error
					raise Error.new(Status::INTERNAL, "Failed to decompress message: #{error.message}")
				end
			end
		end
	end
end
