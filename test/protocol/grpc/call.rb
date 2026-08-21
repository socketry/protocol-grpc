# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/call"
require "protocol/http"
require "async/deadline"

describe Protocol::GRPC::Call do
	let(:headers) {Protocol::HTTP::Headers.new([["authorization", "Bearer token123"]])}
	let(:request) {Protocol::HTTP::Request.new("https", "localhost", "POST", "/service/method", nil, headers, nil)}
	let(:response) {Protocol::HTTP::Response[200, {}, []]}
	
	with ".for" do
		it "creates a call with request and response" do
			call = subject.for(request, response)
			
			expect(call.request).to be == request
			expect(call.response).to be == response
		end
		
		it "computes deadline from grpc-timeout" do
			headers = Protocol::GRPC::Metadata.build(timeout: 0.3)
			request = Protocol::HTTP::Request.new("https", "localhost", "POST", "/service/method", nil, headers, nil)
			call = subject.for(request, response)
			
			expect(call.deadline).to be_a(Async::Deadline)
			expect(call.time_remaining).to be <= 0.3
		end
		
		it "does not set a deadline without grpc-timeout" do
			call = subject.for(request, response)
			
			expect(call.deadline).to be_nil
		end
	end
	
	it "has request" do
		call = subject.new(request)
		expect(call.request).to have_attributes(
			method: be == "POST",
			path: be == "/service/method"
		)
	end
	
	it "extracts metadata" do
		call = subject.new(request)
		expect(call.metadata["authorization"]).to be == "Bearer token123"
	end
	
	with "timeout" do
		it "returns the client supplied timeout in seconds" do
			headers = Protocol::GRPC::Metadata.build(timeout: 0.3)
			request = Protocol::HTTP::Request.new("https", "localhost", "POST", "/service/method", nil, headers, nil)
			call = subject.new(request)
			expect(call.timeout).to be == 0.3
		end
		
		it "returns nil when no timeout was supplied" do
			call = subject.new(request)
			expect(call.timeout).to be_nil
		end
	end
	
	with "status" do
		it "returns the status assigned to the response" do
			Protocol::GRPC::Metadata.assign_status!(response.headers, status: Protocol::GRPC::Status::RESOURCE_EXHAUSTED)
			call = subject.new(request, response)
			
			expect(call.status).to be == Protocol::GRPC::Status::RESOURCE_EXHAUSTED
		end
		
		it "returns nil without an assigned response status" do
			call = subject.new(request, response)
			
			expect(call.status).to be_nil
		end
		
		it "returns nil without a response" do
			call = subject.new(request)
			
			expect(call.status).to be_nil
		end
	end
	
	with "deadline" do
		let(:deadline) {Async::Deadline.start(5.0)}
		
		it "has deadline" do
			call = subject.new(request, deadline: deadline)
			expect(call.deadline).to be == deadline
		end
		
		it "checks if deadline exceeded" do
			call = subject.new(request, deadline: deadline)
			expect(call.deadline_exceeded?).to be == false
		end
		
		it "returns time remaining" do
			call = subject.new(request, deadline: deadline)
			remaining = call.time_remaining
			expect(remaining).to be_a(Numeric)
			expect(remaining).to be <= 5.0
		end
	end
	
	with "no deadline" do
		it "deadline_exceeded? returns false" do
			call = subject.new(request)
			expect(call.deadline_exceeded?).to be == false
		end
		
		it "time_remaining returns nil" do
			call = subject.new(request)
			expect(call.time_remaining).to be_nil
		end
	end
	
	with "peer" do
		it "returns peer information" do
			peer_obj = Object.new
			def peer_obj.to_s
				"127.0.0.1:12345"
			end
			
			req = Protocol::HTTP::Request.new("https", "localhost", "POST", "/service/method", nil, headers, nil)
			req.instance_variable_set(:@peer, peer_obj)
			def req.peer
				@peer
			end
			
			call = subject.new(req)
			expect(call.peer).to be == "127.0.0.1:12345"
		end
	end
end
