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
	
	with ".build_status_headers" do
		it "builds headers with status" do
			headers = subject.build_status_headers(status: Protocol::GRPC::Status::OK)
			status_value = headers["grpc-status"]
			if status_value.is_a?(Protocol::GRPC::Header::Status)
				expect(status_value.to_i).to be == Protocol::GRPC::Status::OK
			else
				status_value = status_value.first if status_value.is_a?(Array)
				expect(status_value.to_s).to be == "0"
			end
		end
		
		it "builds headers with status and message" do
			headers = subject.build_status_headers(
				status: Protocol::GRPC::Status::NOT_FOUND,
				message: "Not found"
			)
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			message_value = headers["grpc-message"]
			message_value = message_value.first if message_value.is_a?(Array)
			expect(status_value.to_s).to be == "5"
			expect(message_value.to_s).to be == "Not%20found"
		end
	end
	
	with ".prepare_trailers!" do
		it "marks headers for trailers" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.prepare_trailers!(headers)
			expect(headers).to be(:trailer?)
		end
	end
	
	with ".add_status_trailer!" do
		it "adds status as trailer" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.add_status_trailer!(headers, status: Protocol::GRPC::Status::OK)
			
			expect(headers).to be(:trailer?)
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
		end
		
		it "adds status and message as trailer" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.add_status_trailer!(
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
	end
	
	with ".add_status_header!" do
		it "adds status as initial header" do
			headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
			subject.add_status_header!(headers, status: Protocol::GRPC::Status::OK)
			
			expect(headers).not.to be(:trailer?)
			status_value = headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			expect(status_value.to_s).to be == "0"
		end
	end
	
	with ".build_trailers_only_response" do
		it "builds trailers-only response" do
			response = subject.build_trailers_only_response(
				status: Protocol::GRPC::Status::NOT_FOUND,
				message: "Not found"
			)
			
			expect(response.status).to be == 200
			expect(response.headers["content-type"]).to be == "application/grpc+proto"
			status_value = response.headers["grpc-status"]
			status_value = status_value.first if status_value.is_a?(Array)
			message_value = response.headers["grpc-message"]
			message_value = message_value.first if message_value.is_a?(Array)
			expect(status_value.to_s).to be == "5"
			expect(message_value.to_s).to be == "Not%20found"
			expect(response.body).to be_nil
		end
	end
end
