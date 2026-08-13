# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/header/status"

describe Protocol::GRPC::Header::Status do
	with ".coerce" do
		it "returns an existing status" do
			status = subject.new(5)
			expect(subject.coerce(status)).to be_equal(status)
		end
	end
	
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
	
	with "#==" do
		it "compares equal status instances" do
			status1 = subject.new(0)
			status2 = subject.new(0)
			expect(status1).to be == status2
		end
		
		it "compares unequal status instances" do
			status1 = subject.new(0)
			status2 = subject.new(1)
			expect(status1).not.to be == status2
		end
		
		it "compares status with integer" do
			status = subject.new(5)
			expect(status).to be == 5
		end
		
		it "compares status with different integer" do
			status = subject.new(5)
			expect(status).not.to be == 3
		end
	end
	
	with "#eql?" do
		it "works same as ==" do
			status1 = subject.new(0)
			status2 = subject.new(0)
			expect(status1.eql?(status2)).to be == true
		end
	end
	
	with "#hash" do
		it "returns consistent hash for same status code" do
			status1 = subject.new(0)
			status2 = subject.new(0)
			expect(status1.hash).to be == status2.hash
		end
		
		it "can be used as hash key" do
			status = subject.new(0)
			hash = {status => "success"}
			expect(hash[subject.new(0)]).to be == "success"
		end
	end
	
	with "#ok?" do
		it "returns true for status code 0" do
			status = subject.new(0)
			expect(status).to be(:ok?)
		end
		
		it "returns false for non-zero status code" do
			status = subject.new(1)
			expect(status.ok?).to be == false
		end
		
		it "returns false for error status" do
			status = subject.new(14)
			expect(status.ok?).to be == false
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
