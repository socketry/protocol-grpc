# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Compatibility shim for the old file name.
# This file is deprecated and will be removed in a future version.
# Please update your code to require 'protocol/grpc/body/writable' instead.

warn "Requiring 'protocol/grpc/body/writable_body' is deprecated. Please require 'protocol/grpc/body/writable' instead.", uplevel: 1 if $VERBOSE

require_relative "writable"

module Protocol
	module GRPC
		module Body
			# Compatibility alias for the old class name.
			# @deprecated Use {Writable} instead.
			WritableBody = Writable
		end
	end
end
