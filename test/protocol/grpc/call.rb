# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/call"
require "protocol/http"
require "async/deadline"

describe Protocol::GRPC::Call do
	let(:headers) {Protocol::HTTP::Headers.new([["authorization", "Bearer token123"]])}
	let(:request) {Protocol::HTTP::Request.new("https", "localhost", "POST", "/service/method", nil, headers, nil)}
	
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
	
	it "is not cancelled by default" do
		call = subject.new(request)
		expect(call).not.to be(:cancelled?)
	end
	
	it "can be cancelled" do
		call = subject.new(request)
		call.cancel!
		expect(call).to be(:cancelled?)
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
