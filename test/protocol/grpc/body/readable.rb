# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/body/readable"
require "protocol/http/body/buffered"
require_relative "../../../../fixtures/protocol/grpc/test_message"

require "zlib"

describe Protocol::GRPC::Body::Readable do
	let(:message_class) {Protocol::GRPC::Fixtures::TestMessage}
	let(:source_body) {Protocol::HTTP::Body::Buffered.new}
	let(:body) {subject.new(source_body, message_class: message_class)}
	
	def write_message(message, compressed: false)
		data = message.to_proto
		compression_flag = compressed ? 1 : 0
		prefix = [compression_flag].pack("C") + [data.bytesize].pack("N")
		source_body.write(prefix + data)
	end
	
	def write_data(data, compressed: false)
		compression_flag = compressed ? 1 : 0
		prefix = [compression_flag].pack("C") + [data.bytesize].pack("N")
		source_body.write(prefix + data)
	end
	
	with ".wrap" do
		it "wraps a message body" do
			message = Struct.new(:body).new(source_body)
			wrapped_body = subject.wrap(message, message_class: message_class)
			
			expect(wrapped_body).to be_a(subject)
			expect(message.body).to be_equal(wrapped_body)
		end
		
		it "returns nil when the message has no body" do
			message = Struct.new(:body).new(nil)
			
			expect(subject.wrap(message)).to be_nil
		end
	end
	
	it "has body attribute" do
		expect(body.body).to be == source_body
	end
	
	with "#read" do
		it "reads single message" do
			message = message_class.new(value: "Hello")
			write_message(message)
			# Don't close the body - let Readable handle it
			
			read_message = body.read
			expect(read_message).to be == message
		end
		
		it "reads multiple messages" do
			message1 = message_class.new(value: "Hello")
			message2 = message_class.new(value: "World")
			write_message(message1)
			write_message(message2)
			# Don't close the body - let Readable handle it
			
			expect(body.read).to be == message1
			expect(body.read).to be == message2
		end
		
		it "returns nil when stream ends" do
			# Empty body should return nil
			expect(body.read).to be_nil
		end
		
		it "works with binary mode (no message_class)" do
			binary_body = subject.new(source_body, message_class: nil)
			data = "Hello World".dup.force_encoding(Encoding::BINARY)
			prefix = [0].pack("C") + [data.bytesize].pack("N")
			source_body.write(prefix + data)
			
			expect(binary_body.read).to be == data
		end
		
		it "handles partial reads correctly" do
			message = message_class.new(value: "Hello")
			data = message.to_proto
			prefix = [0].pack("C") + [data.bytesize].pack("N")
			
			# Write prefix and data separately to test buffering
			source_body.write(prefix)
			source_body.write(data)
			
			read_message = body.read
			expect(read_message).to be == message
		end
		
		it "returns nil when the underlying body reports clean EOF" do
			source_body = Object.new
			def source_body.empty?
				false
			end
			
			def source_body.read
				nil
			end
			
			body = subject.new(source_body)
			expect(body.read).to be_nil
		end
		
		it "raises an error for a truncated prefix" do
			source_body.write("\x00\x00".b)
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
				expect(error.message).to be =~ /expected 5 bytes, received 2/
			end
		end
		
		it "raises an error when a partial prefix is followed by nil" do
			chunks = ["\x00".b, nil]
			source_body = Object.new
			source_body.define_singleton_method(:empty?){false}
			source_body.define_singleton_method(:read){chunks.shift}
			body = subject.new(source_body)
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
				expect(error.message).to be =~ /expected 5 bytes, received 1/
			end
		end
		
		it "raises an error for a truncated payload" do
			write_data("ab")
			framed_data = source_body.read
			source_body.write(framed_data.byteslice(0...5) + "a")
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
				expect(error.message).to be =~ /expected 2 bytes, received 1/
			end
		end
		
		it "raises an error when the payload is missing" do
			source_body.write("\x00".b + [2].pack("N"))
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
				expect(error.message).to be =~ /expected 2 bytes, received 0/
			end
		end
	end
	
	with "#each" do
		it "iterates over messages" do
			message1 = message_class.new(value: "Hello")
			message2 = message_class.new(value: "World")
			write_message(message1)
			write_message(message2)
			
			messages = []
			body.each do |message|
				messages << message
			end
			
			expect(messages).to be == [message1, message2]
		end
		
		it "closes body after iteration" do
			message = message_class.new(value: "Hello")
			write_message(message)
			
			expect(body).to receive(:close)
			body.each{}
		end
		
		it "returns enumerator without block" do
			message = message_class.new(value: "Hello")
			write_message(message)
			
			enumerator = body.each
			expect(enumerator).to be_a(Enumerator)
			expect(enumerator.to_a.length).to be == 1
		end
	end
	
	with "#close" do
		it "closes underlying body" do
			expect(source_body).to receive(:close)
			body.close
		end
		
		it "handles close with error" do
			error = StandardError.new("Test error")
			expect(source_body).to receive(:close).with(error)
			body.close(error)
		end
	end
	
	with "compression" do
		it "handles uncompressed messages" do
			body = subject.new(source_body, message_class: message_class, encoding: nil)
			message = message_class.new(value: "Hello")
			write_message(message, compressed: false)
			
			read_message = body.read
			expect(read_message).to be == message
		end
		
		it "decompresses deflate messages" do
			body = subject.new(source_body, message_class: message_class, encoding: "deflate")
			message = message_class.new(value: "Hello")
			write_data(Zlib::Deflate.deflate(message.to_proto), compressed: true)
			
			expect(body.read).to be == message
		end
		
		it "rejects unsupported encodings" do
			body = subject.new(source_body, message_class: message_class, encoding: "custom")
			message = message_class.new(value: "Hello")
			write_message(message, compressed: true)
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::UNIMPLEMENTED
				expect(error.message).to be =~ /Unsupported compression encoding: "custom"/
			end
		end
		
		it "raises a gRPC error for invalid gzip data" do
			body = subject.new(source_body, encoding: "gzip")
			write_data("invalid", compressed: true)
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
				expect(error.message).to be =~ /Failed to decompress message/
			end
		end
		
		it "raises a gRPC error for invalid deflate data" do
			body = subject.new(source_body, encoding: "deflate")
			write_data("invalid", compressed: true)
			
			expect{body.read}.to raise_exception(Protocol::GRPC::Error) do |error|
				expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
				expect(error.message).to be =~ /Failed to decompress message/
			end
		end
	end
	
	with "empty stream" do
		it "returns nil immediately" do
			# Empty body should return nil
			expect(body.read).to be_nil
		end
	end
end
