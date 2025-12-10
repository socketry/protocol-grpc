# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Mock protobuf message class for testing
module Protocol
	module GRPC
		module Fixtures
			class TestMessage
				attr_accessor :value
				
				def initialize(value: nil)
					@value = value
				end
				
				# Mock protobuf decode method
				def self.decode(data)
					# Simple binary format: first 4 bytes are length, rest is value
					length = data[0...4].unpack1("N")
					value = data[4...(4 + length)].dup.force_encoding(Encoding::UTF_8)
					new(value: value)
				end
				
				# Mock protobuf encode method
				def to_proto
					value_data = (@value || "").dup.force_encoding(Encoding::BINARY)
					[value_data.bytesize].pack("N") + value_data
				end
				
				alias encode to_proto
				
				def ==(other)
					other.is_a?(self.class) && other.value == @value
				end
			end
		end
	end
end
