# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/grpc/metadata"
require "protocol/grpc/status"
require "protocol/http"

describe Protocol::GRPC::Metadata do
	with ".build" do
		it "builds basic gRPC headers" do
			headers = subject.build
			
			expect(headers["content-type"].to_s).to be == "application/grpc+proto"
			expect(headers["te"].to_s).to be == "trailers"
		end
		
		it "builds headers with metadata" do
			headers = subject.build(metadata: {"authorization" => "Bearer token123"})
			
			expect(headers["authorization"].to_s).to be == "Bearer token123"
		end
		
		it "builds headers with timeout" do
			headers = subject.build(timeout: 5.0)
			
			expect(headers["grpc-timeout"].to_s).to be =~ /\d+[SMHmun]/
		end
		
		it "encodes binary metadata" do
			binary_data = "\x00\x01\x02\x03".dup.force_encoding(Encoding::BINARY)
			headers = subject.build(metadata: {"custom-bin" => binary_data})
			
			expect(headers["custom-bin"].to_s).not.to be == binary_data
		end
		
		it "allows a custom content type" do
			headers = subject.build(content_type: "application/grpc+json")
			
			expect(headers["content-type"].to_s).to be == "application/grpc+json"
		end
	end
	
	with ".extract" do
		let(:headers) do
			Protocol::HTTP::Headers.new([
				["content-type", "application/grpc+proto"],
				["authorization", "Bearer token123"],
				["custom-header", "value"],
				["grpc-status", "0"],
				["custom-bin", "AQIDBA=="]
			])
		end
		
		it "extracts application metadata" do
			metadata = subject.extract(headers)
			
			expect(metadata["authorization"]).to be == "Bearer token123"
			expect(metadata["custom-header"]).to be == ["value"]
		end
		
		it "skips reserved headers" do
			metadata = subject.extract(headers)
			
			expect(metadata.key?("content-type")).to be == false
			expect(metadata.key?("grpc-status")).to be == false
		end
		
		it "decodes binary metadata" do
			metadata = subject.extract(headers)
			
			expect(metadata["custom-bin"]).to be == ["\x01\x02\x03\x04".dup.force_encoding(Encoding::BINARY)]
		end
		
		it "decodes scalar binary metadata" do
			headers = Object.new
			def headers.to_h
				{"custom-bin" => "AQIDBA=="}
			end
			
			metadata = subject.extract(headers)
			expect(metadata["custom-bin"]).to be == "\x01\x02\x03\x04".dup.force_encoding(Encoding::BINARY)
		end
	end
	
	with ".extract_status" do
		it "extracts status from headers" do
			headers = Protocol::HTTP::Headers.new([%w[grpc-status 0]], nil, policy: Protocol::GRPC::HEADER_POLICY)
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::OK
		end
		
		it "returns UNKNOWN if status not present" do
			headers = Protocol::HTTP::Headers.new
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::UNKNOWN
		end
		
		it "extracts non-zero status" do
			headers = Protocol::HTTP::Headers.new([%w[grpc-status 14]])
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::UNAVAILABLE
		end
	end
	
	with ".extract_message" do
		it "extracts message from headers" do
			headers = Protocol::HTTP::Headers.new([["grpc-message", "Error%20message"]])
			expect(subject.extract_message(headers)).to be == "Error message"
		end
		
		it "returns nil if message not present" do
			headers = Protocol::HTTP::Headers.new
			expect(subject.extract_message(headers)).to be_nil
		end
	end
	
	with ".assign_status!" do
		it "assigns status to headers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.assign_status!(headers, status: Protocol::GRPC::Status::OK)
			
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
		end
		
		it "assigns status and message to headers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.assign_status!(
				headers,
				status: Protocol::GRPC::Status::INTERNAL,
				message: "Internal error"
			)
			
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			message_value = headers["grpc-message"]
			message_value = message_value.first if message_value.is_a?(Array)
			expect(status_value.to_s).to be == "13"
			expect(message_value.to_s).to be == "Internal%20error"
		end
		
		it "assigns status to trailers when headers are marked as trailers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			headers.trailer!
			subject.assign_status!(headers, status: Protocol::GRPC::Status::OK)
			
			expect(headers).to be(:trailer?)
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
		end
		
		it "supports add_status! alias for backward compatibility" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.add_status!(headers, status: Protocol::GRPC::Status::OK, message: "Test")
			
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
			
			message_value = headers["grpc-message"]
			message_value = message_value.first if message_value.is_a?(Array)
			expect(message_value.to_s).to be == "Test"
		end
		
		it "uses the error message when no message is given" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.assign_status!(headers, status: Protocol::GRPC::Status::INTERNAL, error: StandardError.new("Failure"))
			
			expect(subject.extract_message(headers)).to be == "Failure"
		end
	end
	
end
