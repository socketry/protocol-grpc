# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/header/timeout"

describe Protocol::GRPC::Header::Timeout do
	with ".coerce" do
		it "coerces a string timeout" do
			expect(subject.coerce("5S")).to be == "5S"
		end
	end
	
	with ".format" do
		it "preserves fractional seconds and partial minutes and hours" do
			[1.5, 59.9, 90, 3599, 3601, 7199, 0.0000000001].each do |duration|
				encoded = subject.format(duration)
				decoded = subject.new(encoded).to_seconds
				expect(decoded).to be >= duration
				expect(decoded - duration).to be < 0.000001
			end
		end
		
		it "rounds up when the finest units exceed eight digits" do
			duration = 123456.789123
			encoded = subject.format(duration)
			expect(encoded).to be =~ /\A\d{1,8}[HMSmun]\z/
			expect(subject.new(encoded).to_seconds).to be >= duration
			expect(subject.new(encoded).to_seconds - duration).to be < 1
		end
		
		it "represents zero without a negative or invalid wire value" do
			expect(subject.new(subject.format(0)).to_seconds).to be == 0
		end
		
		it "rejects negative, non-finite, and out-of-range durations" do
			[-1, Float::INFINITY, Float::NAN].each do |duration|
				expect{subject.format(duration)}.to raise_exception(ArgumentError)
			end
			expect{subject.format(100_000_000 * 3600)}.to raise_exception(RangeError)
		end
		
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
				"123456789S",
				"1s",
				"oneS",
			]
			
			invalid_values.each do |value|
				expect{subject.new(value).to_seconds}.to raise_exception(ArgumentError, message: be == "Invalid grpc-timeout: #{value.inspect}")
			end
		end
	end
	
	with "#<<" do
		it "replaces the timeout and returns itself" do
			timeout = subject.new("5S")
			expect(timeout << "10S").to be_equal(timeout)
			expect(timeout).to be == "10S"
		end
	end
	
	with ".trailer?" do
		it "returns false" do
			expect(subject.trailer?).to be == false
		end
	end
end
