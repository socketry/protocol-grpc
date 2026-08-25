# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/status"

describe Protocol::GRPC::Status do
	let(:statuses) do
		subject.constants(false).each_with_object({}) do |constant_name, statuses|
			status_code = subject.const_get(constant_name)
			statuses[status_code] = constant_name.to_s if status_code.is_a?(Integer)
		end
	end
	
	it "defines status codes" do
		expect(subject.constants).not.to be(:empty?)
	end
	
	it "defines OK status" do
		expect(subject::OK).to be == 0
	end
	
	it "defines CANCELLED status" do
		expect(subject::CANCELLED).to be == 1
	end
	
	it "defines UNKNOWN status" do
		expect(subject::UNKNOWN).to be == 2
	end
	
	it "defines INVALID_ARGUMENT status" do
		expect(subject::INVALID_ARGUMENT).to be == 3
	end
	
	it "defines DEADLINE_EXCEEDED status" do
		expect(subject::DEADLINE_EXCEEDED).to be == 4
	end
	
	it "defines NOT_FOUND status" do
		expect(subject::NOT_FOUND).to be == 5
	end
	
	it "defines INTERNAL status" do
		expect(subject::INTERNAL).to be == 13
	end
	
	it "defines UNAVAILABLE status" do
		expect(subject::UNAVAILABLE).to be == 14
	end
	
	it "defines UNAUTHENTICATED status" do
		expect(subject::UNAUTHENTICATED).to be == 16
	end
	
	with "NAMES" do
		it "has canonical names for all status codes" do
			expect(subject::NAMES).to be == statuses
		end
	end
end
