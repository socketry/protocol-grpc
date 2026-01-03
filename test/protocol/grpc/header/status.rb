# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/header/status"

describe Protocol::GRPC::Header::Status do
	with ".parse" do
		it "parses string value to integer" do
			status = subject.parse("0")
			expect(status.to_i).to be == 0
		end
		
		it "parses numeric string" do
			status = subject.parse("14")
			expect(status.to_i).to be == 14
		end
	end
	
	with "#initialize" do
		it "accepts integer value" do
			status = subject.new(0)
			expect(status.to_i).to be == 0
		end
		
		it "accepts string value" do
			status = subject.new("5")
			expect(status.to_i).to be == 5
		end
	end
	
	with "#to_i" do
		it "returns integer status code" do
			status = subject.new(13)
			expect(status.to_i).to be == 13
		end
	end
	
	with "#to_s" do
		it "returns string representation of status code" do
			status = subject.new(0)
			expect(status.to_s).to be == "0"
		end
		
		it "converts integer to string" do
			status = subject.new(14)
			expect(status.to_s).to be == "14"
		end
	end
	
	with "#<<" do
		it "merges new integer value" do
			status = subject.new(0)
			status << 1
			expect(status.to_i).to be == 1
		end
		
		it "merges new string value" do
			status = subject.new(0)
			status << "5"
			expect(status.to_i).to be == 5
		end
		
		it "returns self for chaining" do
			status = subject.new(0)
			result = status << 1
			expect(result).to be_equal(status)
		end
	end
	
	with ".trailer?" do
		it "returns true as grpc-status can appear in trailers" do
			expect(subject).to be(:trailer?)
		end
	end
end
