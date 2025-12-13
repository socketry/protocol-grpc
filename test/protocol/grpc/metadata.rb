# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/metadata"
require "protocol/grpc/status"
require "protocol/http"

describe Protocol::GRPC::Metadata do
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
			headers = Protocol::HTTP::Headers.new([%w[grpc-status 14]], nil, policy: Protocol::GRPC::HEADER_POLICY)
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::UNAVAILABLE
		end
	end
	
	with ".extract_message" do
		it "extracts message from headers" do
			headers = Protocol::HTTP::Headers.new([["grpc-message", "Error%20message"]], nil, policy: Protocol::GRPC::HEADER_POLICY)
			expect(subject.extract_message(headers)).to be == "Error message"
		end
		
		it "returns nil if message not present" do
			headers = Protocol::HTTP::Headers.new
			expect(subject.extract_message(headers)).to be_nil
		end
	end
	
	with ".add_status!" do
		it "adds status to headers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.add_status!(headers, status: Protocol::GRPC::Status::OK)
			
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
		end
		
		it "adds status and message to headers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.add_status!(
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
		
		it "adds status to trailers when headers are marked as trailers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			headers.trailer!
			subject.add_status!(headers, status: Protocol::GRPC::Status::OK)
			
			expect(headers).to be(:trailer?)
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
		end
	end
	
end
