# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/header/message"

describe Protocol::GRPC::Header::Message do
	with ".parse" do
		it "parses string value" do
			message = subject.parse("Error%20occurred")
			expect(message).to be == "Error%20occurred"
		end
	end
	
	with "#initialize" do
		it "accepts string value" do
			message = subject.new("Test message")
			expect(message).to be == "Test message"
		end
	end
	
	with "#decode" do
		it "decodes URL-encoded message" do
			message = subject.new("Error%20occurred")
			expect(message.decode).to be == "Error occurred"
		end
		
		it "decodes special characters" do
			message = subject.new("Error%3A%20not%20found")
			expect(message.decode).to be == "Error: not found"
		end
		
		it "handles unencoded message" do
			message = subject.new("Simple error")
			expect(message.decode).to be == "Simple error"
		end
	end
	
	with ".encode" do
		it "encodes message for headers" do
			encoded = subject.encode("Error occurred")
			expect(encoded).to be == "Error%20occurred"
		end
		
		it "encodes special characters" do
			encoded = subject.encode("Error: not found")
			expect(encoded).to be == "Error%3A%20not%20found"
		end
		
		it "does not use plus for spaces" do
			encoded = subject.encode("Test message")
			expect(encoded).not.to be =~ /\+/
			expect(encoded).to be =~ /%20/
		end
	end
	
	with "#<<" do
		it "merges new string value" do
			message = subject.new("Old message")
			message << "New message"
			expect(message).to be == "New message"
		end
		
		it "converts non-string to string" do
			message = subject.new("Old")
			message << 123
			expect(message).to be == "123"
		end
		
		it "returns self for chaining" do
			message = subject.new("Old")
			result = message << "New"
			expect(result).to be_equal(message)
		end
	end
	
	with ".trailer?" do
		it "returns true as grpc-message can appear in trailers" do
			expect(subject).to be(:trailer?)
		end
	end
end
