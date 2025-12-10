# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

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
		it "builds basic gRPC headers" do
			headers = subject.build_headers
			
			content_type = headers["content-type"]
			content_type = content_type.first if content_type.is_a?(Array)
			te_value = headers["te"]
			te_value = te_value.first if te_value.is_a?(Array)
			
			expect(content_type.to_s).to be == "application/grpc+proto"
			expect(te_value.to_s).to be == "trailers"
		end
		
		it "builds headers with metadata" do
			headers = subject.build_headers(metadata: { "authorization" => "Bearer token123" })
			
			auth_value = headers["authorization"]
			auth_value = auth_value.first if auth_value.is_a?(Array)
			expect(auth_value.to_s).to be == "Bearer token123"
		end
		
		it "builds headers with timeout" do
			headers = subject.build_headers(timeout: 5.0)
			
			timeout_value = headers["grpc-timeout"]
			timeout_value = timeout_value.first if timeout_value.is_a?(Array)
			expect(timeout_value.to_s).to be_a(String)
			expect(timeout_value.to_s).to be =~ /\d+[SMHmun]/
		end
		
		it "encodes binary metadata" do
			binary_data = "\x00\x01\x02\x03".dup.force_encoding(Encoding::BINARY)
			headers = subject.build_headers(metadata: { "custom-bin" => binary_data })
			
			custom_value = headers["custom-bin"]
			custom_value = custom_value.first if custom_value.is_a?(Array)
			expect(custom_value.to_s).not.to be == binary_data
			expect(custom_value.to_s).to be_a(String)
		end
		
		it "allows custom content type" do
			headers = subject.build_headers(content_type: "application/grpc+json")
			content_type = headers["content-type"]
			content_type = content_type.first if content_type.is_a?(Array)
			expect(content_type.to_s).to be == "application/grpc+json"
		end
	end
	
	with ".extract_metadata" do
		let(:headers) do
			Protocol::HTTP::Headers.new([
				["content-type", "application/grpc+proto"],
																																				["authorization", "Bearer token123"],
																																				["custom-header", "value"],
																																				["grpc-status", "0"],
																																				["custom-bin", "AQIDBA=="] # Base64 encoded binary
			])
		end
		
		it "extracts metadata from headers" do
			metadata = subject.extract_metadata(headers)
			
			expect(metadata["authorization"]).to be == "Bearer token123"
			expect(metadata["custom-header"]).to be == "value"
		end
		
		it "skips reserved headers" do
			metadata = subject.extract_metadata(headers)
			
			expect(metadata.key?("content-type")).to be == false
			expect(metadata.key?("grpc-status")).to be == false
		end
		
		it "decodes binary metadata" do
			metadata = subject.extract_metadata(headers)
			
			expect(metadata["custom-bin"]).to be == "\x01\x02\x03\x04".dup.force_encoding(Encoding::BINARY)
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
