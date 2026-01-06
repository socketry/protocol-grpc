# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/header"

describe Protocol::GRPC::HEADER_POLICY do
	it "includes grpc-status mapping" do
		expect(subject["grpc-status"]).to be == Protocol::GRPC::Header::Status
	end
	
	it "includes grpc-message mapping" do
		expect(subject["grpc-message"]).to be == Protocol::GRPC::Header::Message
	end
	
	it "is frozen" do
		expect(subject).to be(:frozen?)
	end
end
