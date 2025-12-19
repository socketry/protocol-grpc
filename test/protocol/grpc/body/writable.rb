# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/body/writable"
require "protocol/http/body/writable"
require_relative "../../../../fixtures/protocol/grpc/test_message"

describe Protocol::GRPC::Body::Writable do
	let(:body) {subject.new}
	let(:message_class) {Protocol::GRPC::Fixtures::TestMessage}
	
	def read_message(raw_body)
		# Read chunks until we have at least 5 bytes for prefix
		buffer = String.new.force_encoding(Encoding::BINARY)
		while buffer.bytesize < 5
			chunk = raw_body.read
			return nil unless chunk
			
			buffer << chunk
		end
		
		# Extract prefix
		prefix = buffer[0...5]
		buffer = buffer[5..]
		
		prefix[0].unpack1("C")
		length = prefix[1..4].unpack1("N")
		
		# Read message data
		while buffer.bytesize < length
			chunk = raw_body.read
			return nil unless chunk
			
			buffer << chunk
		end
		
		data = buffer[0...length]
		
		# Decompress if needed (simplified - assumes no compression for now)
		message_class.decode(data)
	end
	
	it "is not closed by default" do
		expect(body).not.to be(:closed?)
	end
	
	with "#write" do
		it "writes single message" do
			message = message_class.new(value: "Hello")
			body.write(message)
			body.close_write
			
			read_message = read_message(body)
			expect(read_message).to be == message
		end
		
		it "writes multiple messages" do
			message1 = message_class.new(value: "Hello")
			message2 = message_class.new(value: "World")
			body.write(message1)
			body.write(message2)
			body.close_write
			
			expect(read_message(body)).to be == message1
			expect(read_message(body)).to be == message2
		end
		
		it "writes raw binary data" do
			data = "Hello World".dup.force_encoding(Encoding::BINARY)
			body.write(data)
			body.close_write
			
			# Read prefix
			buffer = String.new.force_encoding(Encoding::BINARY)
			while buffer.bytesize < 5
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			prefix = buffer[0...5]
			buffer = buffer[5..]
			
			compressed = prefix[0].unpack1("C")
			length = prefix[1..4].unpack1("N")
			
			# Read data
			while buffer.bytesize < length
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			read_data = buffer[0...length]
			
			expect(compressed).to be == 0
			expect(read_data).to be == data
		end
		
		it "uses to_proto method when available" do
			message = message_class.new(value: "Hello")
			body.write(message)
			body.close_write
			
			# Verify the message was encoded correctly
			read_message = read_message(body)
			expect(read_message.value).to be == "Hello"
		end
		
		it "uses encode method when to_proto not available" do
			message = Object.new
			def message.encode
				"encoded".dup.force_encoding(Encoding::BINARY)
			end
			
			body.write(message)
			body.close_write
			
			# Read prefix
			buffer = String.new.force_encoding(Encoding::BINARY)
			while buffer.bytesize < 5
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			prefix = buffer[0...5]
			buffer = buffer[5..]
			
			length = prefix[1..4].unpack1("N")
			
			# Read data
			while buffer.bytesize < length
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			read_data = buffer[0...length]
			
			expect(read_data).to be == "encoded"
		end
		
		it "raises error for invalid message" do
			invalid_message = Object.new
			
			expect do
				body.write(invalid_message)
			end.to raise_exception(ArgumentError, message: be =~ /to_proto or :encode/)
		end
	end
	
	with "#close_write" do
		it "closes write side" do
			body.write(message_class.new(value: "Hello"))
			body.close_write
			
			# After close_write, the body is closed but still readable
			expect(body).to be(:closed?)
			expect(body).to be(:ready?)
		end
		
		it "allows reading after close_write" do
			message = message_class.new(value: "Hello")
			body.write(message)
			body.close_write
			
			read_message = read_message(body)
			expect(read_message).to be == message
		end
	end
	
	with "compression" do
		it "writes uncompressed messages by default" do
			body = subject.new(encoding: nil)
			message = message_class.new(value: "Hello")
			body.write(message)
			body.close_write
			
			# Read prefix
			buffer = String.new.force_encoding(Encoding::BINARY)
			while buffer.bytesize < 5
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			prefix = buffer[0...5]
			
			compressed = prefix[0].unpack1("C")
			expect(compressed).to be == 0
		end
		
		it "can override compression per message" do
			body = subject.new(encoding: nil)
			message = message_class.new(value: "Hello")
			body.write(message, compressed: false)
			body.close_write
			
			# Read prefix
			buffer = String.new.force_encoding(Encoding::BINARY)
			while buffer.bytesize < 5
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			prefix = buffer[0...5]
			
			compressed = prefix[0].unpack1("C")
			expect(compressed).to be == 0
		end
	end
	
	with "message framing" do
		it "includes compression flag in prefix" do
			message = message_class.new(value: "Hello")
			body.write(message)
			body.close_write
			
			# Read prefix
			buffer = String.new.force_encoding(Encoding::BINARY)
			while buffer.bytesize < 5
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			prefix = buffer[0...5]
			
			expect(prefix.bytesize).to be == 5
			
			compressed = prefix[0].unpack1("C")
			length = prefix[1..4].unpack1("N")
			
			expect(compressed).to be_a(Integer)
			expect(length).to be_a(Integer)
			expect(length).to be > 0
		end
		
		it "validates message class when specified" do
			typed_body = subject.new(message_class: message_class)
			correct_message = message_class.new(value: "Hello")
			wrong_message = Object.new
			def wrong_message.to_proto
				"invalid"
			end
			
			# Should accept correct message class
			typed_body.write(correct_message)
			
			# Should reject wrong message class
			begin
				typed_body.write(wrong_message)
				raise "Expected TypeError"
			rescue TypeError => error
				expect(error.message).to be =~ /Expected #{message_class}/
			end
		end
		
		it "allows any message when message_class is nil" do
			untyped_body = subject.new(message_class: nil)
			message = message_class.new(value: "Hello")
			untyped_body.write(message)
			
			# Should also allow raw strings
			untyped_body.write("raw binary")
		end
		
		it "allows raw strings even when message_class is specified" do
			typed_body = subject.new(message_class: message_class)
			# Raw strings should bypass validation (for channel adapters)
			typed_body.write("raw binary data")
		end
		
		it "writes correct message length" do
			message = message_class.new(value: "Hello")
			expected_data = message.to_proto
			body.write(message)
			body.close_write
			
			# Read prefix
			buffer = String.new.force_encoding(Encoding::BINARY)
			while buffer.bytesize < 5
				chunk = body.read
				break unless chunk
				
				buffer << chunk
			end
			prefix = buffer[0...5]
			
			length = prefix[1..4].unpack1("N")
			expect(length).to be == expected_data.bytesize
		end
	end
end



