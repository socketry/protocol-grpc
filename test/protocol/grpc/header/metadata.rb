# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/grpc/header/metadata"

describe Protocol::GRPC::Header::Metadata do
	with ".trailer?" do
		it "returns true as grpc-metadata can appear in trailers" do
			expect(subject).to be(:trailer?)
		end
	end
end
