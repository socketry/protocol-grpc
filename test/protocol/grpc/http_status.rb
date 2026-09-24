# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/status"

describe Protocol::GRPC::Status do
	with ".for_http_status" do
		it "maps HTTP errors without a grpc-status" do
			{400 => 13, 401 => 16, 403 => 7, 404 => 12, 429 => 14, 502 => 14, 503 => 14, 504 => 14, 200 => 2, 500 => 2}.each do |http, grpc|
				expect(subject.for_http_status(http)).to be == grpc
			end
		end
	end
end
