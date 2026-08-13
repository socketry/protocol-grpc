# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/grpc/metadata"
require "protocol/grpc/status"
require "protocol/http"

describe Protocol::GRPC::Metadata do
	def raw_headers(values)
		Class.new do
			attr_accessor :policy
			
			define_method(:initialize) do |values|
				@values = values
			end
			
			define_method(:[]) do |key|
				@values[key]
			end
		end.new(values)
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
			headers = Protocol::HTTP::Headers.new([%w[grpc-status 14]], nil, policy: Protocol::GRPC::HEADER_POLICY)
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::UNAVAILABLE
		end
		
		it "extracts a raw scalar status" do
			headers = raw_headers("grpc-status" => "14")
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::UNAVAILABLE
		end
		
		it "extracts a raw array status" do
			headers = raw_headers("grpc-status" => [nil, "13"])
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::INTERNAL
		end
		
		it "extracts a deeply nested raw array status" do
			status = Class.new(Array) do
				def flatten
					[[["5"]]]
				end
			end.new
			headers = raw_headers("grpc-status" => status)
			
			expect(subject.extract_status(headers)).to be == Protocol::GRPC::Status::NOT_FOUND
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
		
		it "extracts a raw scalar message" do
			headers = raw_headers("grpc-message" => "Error%20message")
			expect(subject.extract_message(headers)).to be == "Error message"
		end
		
		it "extracts a raw array message" do
			headers = raw_headers("grpc-message" => ["Error%20message"])
			expect(subject.extract_message(headers)).to be == "Error message"
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
