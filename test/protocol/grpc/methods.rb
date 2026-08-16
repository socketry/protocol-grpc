# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/grpc/methods"
require "protocol/http"

describe Protocol::GRPC::Methods do
	with ".build_path" do
		it "builds gRPC path from service and method" do
			path = subject.build_path("my_service.Greeter", "SayHello")
			expect(path).to be == "/my_service.Greeter/SayHello"
		end
	end
	
	with ".parse_path" do
		it "parses service and method from gRPC path" do
			service, method = subject.parse_path("/my_service.Greeter/SayHello")
			expect(service).to be == "my_service.Greeter"
			expect(method).to be == "SayHello"
		end
	end
	
	with ".build_headers" do
		it "delegates to Metadata.build" do
			headers = subject.build_headers(metadata: { "authorization" => "Bearer token123" })
			
			expect(headers["authorization"].to_s).to be == "Bearer token123"
		end
	end
	
	with ".extract_metadata" do
		it "delegates to Metadata.extract" do
			headers = Protocol::HTTP::Headers.new([["authorization", "Bearer token123"]])
			metadata = subject.extract_metadata(headers)
			
			expect(metadata["authorization"]).to be == "Bearer token123"
		end
	end
	
	with ".format_timeout" do
		it "formats seconds" do
			expect(subject.format_timeout(5)).to be == "5S"
		end
		
		it "formats minutes" do
			expect(subject.format_timeout(120)).to be == "2M"
		end
		
		it "formats hours" do
			expect(subject.format_timeout(7200)).to be == "2H"
		end
		
		it "formats milliseconds" do
			expect(subject.format_timeout(0.5)).to be == "500m"
		end
		
		it "formats microseconds" do
			expect(subject.format_timeout(0.0005)).to be == "500u"
		end
		
		it "formats nanoseconds" do
			expect(subject.format_timeout(0.0000005)).to be == "500n"
		end
	end
	
	with ".parse_timeout" do
		it "parses seconds" do
			expect(subject.parse_timeout("5S")).to be == 5
		end
		
		it "parses minutes" do
			expect(subject.parse_timeout("2M")).to be == 120
		end
		
		it "parses hours" do
			expect(subject.parse_timeout("2H")).to be == 7200
		end
		
		it "parses milliseconds" do
			expect(subject.parse_timeout("500m")).to be == 0.5
		end
		
		it "parses microseconds" do
			expect(subject.parse_timeout("500u")).to be == 0.0005
		end
		
		it "parses nanoseconds" do
			expect(subject.parse_timeout("500n")).to be == 0.0000005
		end
		
		it "returns nil for invalid format" do
			expect(subject.parse_timeout("invalid")).to be_nil
		end
		
		it "returns nil for nil input" do
			expect(subject.parse_timeout(nil)).to be_nil
		end
	end
end
