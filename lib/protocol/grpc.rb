# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "grpc/version"

require_relative "grpc/status"
require_relative "grpc/error"
require_relative "grpc/methods"
require_relative "grpc/header"
require_relative "grpc/metadata"
require_relative "grpc/call"
require_relative "grpc/body/readable_body"
require_relative "grpc/body/writable_body"
require_relative "grpc/interface"
require_relative "grpc/middleware"
require_relative "grpc/health_check"

module Protocol
	# Protocol abstractions for gRPC, built on top of `protocol-http`.
	#
	# gRPC is an RPC framework that runs over HTTP/2. It uses Protocol Buffers for serialization
	# and supports four types of RPC patterns:
	#
	# 1. **Unary RPC**: Single request, single response
	# 2. **Client Streaming**: Stream of requests, single response
	# 3. **Server Streaming**: Single request, stream of responses
	# 4. **Bidirectional Streaming**: Stream of requests, stream of responses
	#
	# This gem provides **protocol-level abstractions only** - no networking, no client/server implementations.
	# Those should be built on top in separate gems (e.g., `async-grpc`).
	module GRPC
	end
end
