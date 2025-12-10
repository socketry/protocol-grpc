# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http"
require "zlib"

module Protocol
	module GRPC
		module Body
			# Reads length-prefixed gRPC messages from an HTTP body
			# This is the standard readable body for gRPC - all gRPC responses use message framing
			class ReadableBody
				# @parameter body [Protocol::HTTP::Body::Readable] The underlying HTTP body
				# @parameter message_class [Class, nil] Protobuf message class with .decode method
				#   If nil, returns raw binary data (useful for channel adapters)
				# @parameter encoding [String, nil] Compression encoding (from grpc-encoding header)
				def initialize(body, message_class: nil, encoding: nil)
					@body = body
					@message_class = message_class
					@encoding = encoding
					@buffer = String.new.force_encoding(Encoding::BINARY)
					@closed = false
				end
				
				# The input body.
				# @attribute [Protocol::HTTP::Body::Readable]
				attr_reader :body
				
				# The compression encoding.
				# @attribute [String, nil]
				attr_reader :encoding
				
				# Close the input and output bodies.
				def close(error = nil)
					@closed = true
					
					if @body
						@body.close(error)
						@body = nil
					end
					
					nil
				end
				
				# Whether the stream has been closed.
				def closed?
					@closed or @body.nil?
				end
				
				# Whether there are any input chunks remaining?
				def empty?
					@body.nil?
				end
				
				# Read the next gRPC message
				# @returns [Object | String | Nil] Decoded message, raw binary, or nil if stream ended
				def read
					return nil if closed?
					
					# Read 5-byte prefix: 1 byte compression flag + 4 bytes length
					prefix = read_exactly(5)
					return nil unless prefix
					
					compressed = prefix[0].unpack1("C") == 1
					length = prefix[1..4].unpack1("N")
					
					# Read the message body
					data = read_exactly(length)
					return nil unless data
					
					# Decompress if needed
					data = decompress(data) if compressed
					
					# Decode using message class if provided, otherwise return binary
					# This allows binary mode for channel adapters
					if @message_class
						# Use protobuf gem's decode method
						@message_class.decode(data)
					else
						data # Return raw binary
					end
				end
				
				# Enumerate all messages until finished, then invoke {close}.
				# @yields {|message| ...} The block to call with each message.
				def each
					return to_enum unless block_given?
					
					error = nil
					begin
						while (message = read)
							yield message
						end
					rescue StandardError => e
						error = e
						raise
					ensure
						close(error)
					end
				end
				
			private
				
				def read_exactly(n)
					# Fill buffer until we have enough data
					while @buffer.bytesize < n
						return nil if closed?
						
						# Read chunk from underlying body
						chunk = @body.read
						
						if chunk.nil?
							# End of stream
							if @body && !@closed
								@body.close
								@closed = true
							end
							return nil
						end
						
						# Append to buffer
						@buffer << chunk.force_encoding(Encoding::BINARY)
						
						# Check if body is empty and close if needed
						if @body.empty?
							@body.close
							@closed = true
						end
					end
					
					# Extract the required data
					data = @buffer[0...n]
					@buffer = @buffer[n..]
					data
				end
				
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
