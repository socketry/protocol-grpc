# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/header/timeout"

describe Protocol::GRPC::Header::Timeout do
	with ".format" do
		it "formats seconds" do
			expect(subject.format(5)).to be == "5S"
		end
		
		it "formats minutes" do
			expect(subject.format(120)).to be == "2M"
		end
		
		it "formats hours" do
			expect(subject.format(7200)).to be == "2H"
		end
		
		it "formats milliseconds" do
			expect(subject.format(0.5)).to be == "500m"
		end
		
		it "formats microseconds" do
			expect(subject.format(0.0005)).to be == "500u"
		end
		
		it "formats nanoseconds" do
			expect(subject.format(0.0000005)).to be == "500n"
		end
	end
	
	with "#to_seconds" do
		it "parses seconds" do
			expect(subject.new("5S").to_seconds).to be == 5
		end
		
		it "parses minutes" do
			expect(subject.new("2M").to_seconds).to be == 120
		end
		
		it "parses hours" do
			expect(subject.new("2H").to_seconds).to be == 7200
		end
		
		it "parses milliseconds" do
			expect(subject.new("500m").to_seconds).to be == 0.5
		end
		
		it "parses microseconds" do
			expect(subject.new("500u").to_seconds).to be == 0.0005
		end
		
		it "parses nanoseconds" do
			expect(subject.new("500n").to_seconds).to be == 0.0000005
		end
		
		it "raises an argument error for invalid values" do
			invalid_values = [
				"",
				"0S",
				"01S",
				"123456789S",
				"1s",
				"oneS",
			]
			
			invalid_values.each do |value|
				expect{subject.new(value).to_seconds}.to raise_exception(ArgumentError, message: be == "Invalid grpc-timeout: #{value.inspect}")
			end
		end
	end
end
