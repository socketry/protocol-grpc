# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/header/encoding"

describe Protocol::GRPC::Header::Encoding do
	with ".coerce" do
		it "coerces values to strings" do
			expect(subject.coerce(:gzip)).to be == "gzip"
		end
	end
	
	with "#identity?" do
		it "recognizes identity and empty encodings" do
			expect(subject.new("identity")).to be(:identity?)
			expect(subject.new("")).to be(:identity?)
		end
		
		it "rejects compressed encodings" do
			expect(subject.new("gzip")).not.to be(:identity?)
		end
	end
	
	with "#<<" do
		it "replaces the encoding and returns itself" do
			encoding = subject.new("identity")
			expect(encoding << :gzip).to be_equal(encoding)
			expect(encoding).to be == "gzip"
		end
	end
	
	with ".trailer?" do
		it "returns false" do
			expect(subject.trailer?).to be == false
		end
	end
end
