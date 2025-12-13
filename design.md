# Protocol::GRPC Design

Protocol abstractions for gRPC, built on top of `protocol-http`.

## Overview

gRPC is an RPC framework that runs over HTTP/2. It uses Protocol Buffers for serialization and supports four types of RPC patterns:

1. **Unary RPC**: Single request, single response
2. **Client Streaming**: Stream of requests, single response
3. **Server Streaming**: Single request, stream of responses
4. **Bidirectional Streaming**: Stream of requests, stream of responses

## Architecture

Following the patterns from `Protocol::HTTP`, Protocol::GRPC provides **protocol-level abstractions only** - no networking, no client/server implementations. Those should be built on top in separate gems (e.g., `async-grpc`).

The protocol layer describes:
- How to frame gRPC messages (length-prefixed format)
- How to encode/decode gRPC metadata and trailers
- Status codes and error handling
- Request/response structure

It does NOT include:
- Actual network I/O
- Connection management
- Client or server implementations
- Concurrency primitives

### Core Components Summary

The protocol layer provides these core abstractions:

1. **Message Interface** - `Protocol::GRPC::Message` and `MessageHelpers`
2. **Path Handling** - `Protocol::GRPC::Methods` (build/parse paths, headers, timeouts)
3. **Metadata** - `Protocol::GRPC::Metadata` (extract status, build trailers)
4. **Body Framing** - `Protocol::GRPC::Body::Readable` and `Body::Writable`
5. **Status Codes** - `Protocol::GRPC::Status` constants
6. **Errors** - `Protocol::GRPC::Error` hierarchy
7. **Call Context** - `Protocol::GRPC::Call` (deadline tracking, metadata)
8. **Server Middleware** - `Protocol::GRPC::Middleware` (handles gRPC requests)
9. **Health Check** - `Protocol::GRPC::HealthCheck` protocol
10. **Code Generation** - `Protocol::GRPC::Generator` (parse .proto, generate stubs)

**Key Design Principles:**
- gRPC bodies are **always** message-framed (never raw bytes)
- Use `Body::Readable` not `Body::Message` (it's the standard for gRPC)
- Use `Body::Writable` not `Body::MessageWriter` (it's the standard for gRPC)
- Compression is built-in via `encoding:` parameter (not separate wrapper)
- Binary mode: pass `message_class: nil` to work with raw bytes

### Detailed Components

#### 1. `Protocol::GRPC::Message`

Interface for protobuf messages. Any protobuf implementation can conform to this:

```ruby
module Protocol
	module GRPC
		# Defines the interface that protobuf messages should implement
		# to work with Protocol::GRPC body encoding/decoding.
		#
		# Google's protobuf-ruby gem already provides these methods on generated classes:
		# - MyMessage.decode(binary_string)
		# - message_instance.to_proto
		module Message
			# Decode a binary protobuf string into a message instance
			# @parameter data [String] Binary protobuf data
			# @returns [Object] Decoded message instance
			def decode(data)
				raise NotImplementedError
			end
			
			# Encode a message instance to binary protobuf format
			# @returns [String] Binary protobuf data
			def encode
				raise NotImplementedError
			end
			
			# Alias for encode to match google-protobuf convention
			alias to_proto encode
		end
		
		# Helper methods for working with protobuf messages
		module MessageHelpers
			# Check if a class/object supports the protobuf message interface
			# @parameter klass [Class, Object] The class or instance to check
			# @returns [Boolean]
			def self.protobuf?(klass)
				klass.respond_to?(:decode) && (klass.respond_to?(:encode) || klass.respond_to?(:to_proto))
			end
			
			# Encode a message using the appropriate method
			# @parameter message [Object] Message instance
			# @returns [String] Binary protobuf data
			def self.encode(message)
				if message.respond_to?(:to_proto)
					message.to_proto
				elsif message.respond_to?(:encode)
					message.encode
				else
					raise ArgumentError, "Message must respond to :to_proto or :encode"
				end
			end
			
			# Decode binary data using the message class
			# @parameter klass [Class] Message class with decode method
			# @parameter data [String] Binary protobuf data
			# @returns [Object] Decoded message instance
			def self.decode(klass, data)
				unless klass.respond_to?(:decode)
					raise ArgumentError, "Message class must respond to :decode"
				end
				
				klass.decode(data)
			end
		end
	end
end
```

**Path of Least Resistance**: Google's `protobuf` gem already generates classes with `.decode(binary)` and `#to_proto` methods, so they work out of the box with no wrapper needed.

#### 2. `Protocol::GRPC::Methods`

Helper module for building gRPC-compatible HTTP requests:

```ruby
module Protocol
	module GRPC
		module Methods
			# Build gRPC path from service and method
			# @parameter service [String] e.g., "my_service.Greeter"
			# @parameter method [String] e.g., "SayHello"
			# @returns [String] e.g., "/my_service.Greeter/SayHello"
			def self.build_path(service, method)
				"/#{service}/#{method}"
			end
			
			# Parse service and method from gRPC path
			# @parameter path [String] e.g., "/my_service.Greeter/SayHello"
			# @returns [Array(String, String)] [service, method]
			def self.parse_path(path)
				parts = path.split("/")
				[parts[1], parts[2]]
			end
			
			# Build gRPC request headers
			# @parameter metadata [Hash] Custom metadata key-value pairs
			# @parameter timeout [Numeric] Optional timeout in seconds
			# @returns [Protocol::HTTP::Headers]
			def self.build_headers(metadata: {}, timeout: nil, content_type: "application/grpc+proto")
				headers = Protocol::HTTP::Headers.new
				headers["content-type"] = content_type
				headers["te"] = "trailers"
				headers["grpc-timeout"] = format_timeout(timeout) if timeout
				
				metadata.each do |key, value|
					# Binary headers end with -bin and are base64 encoded
					if key.end_with?("-bin")
						headers[key] = Base64.strict_encode64(value)
					else
						headers[key] = value.to_s
					end
				end
				
				headers
			end
			
			# Extract metadata from gRPC headers
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Hash] Metadata key-value pairs
			def self.extract_metadata(headers)
				metadata = {}
				
				headers.each do |key, value|
					# Skip reserved headers
					next if key.start_with?("grpc-") || key == "content-type" || key == "te"
					
					# Decode binary headers
					if key.end_with?("-bin")
						metadata[key] = Base64.strict_decode64(value)
					else
						metadata[key] = value
					end
				end
				
				metadata
			end
			
			# Format timeout for grpc-timeout header
			# @parameter timeout [Numeric] Timeout in seconds
			# @returns [String] e.g., "1000m" for 1 second
			def self.format_timeout(timeout)
				# gRPC timeout format: value + unit (H=hours, M=minutes, S=seconds, m=milliseconds, u=microseconds, n=nanoseconds)
				if timeout >= 3600
					"#{(timeout / 3600).to_i}H"
				elsif timeout >= 60
					"#{(timeout / 60).to_i}M"
				elsif timeout >= 1
					"#{timeout.to_i}S"
				elsif timeout >= 0.001
					"#{(timeout * 1000).to_i}m"
				elsif timeout >= 0.000001
					"#{(timeout * 1_000_000).to_i}u"
				else
					"#{(timeout * 1_000_000_000).to_i}n"
				end
			end
			
			# Parse grpc-timeout header value
			# @parameter value [String] e.g., "1000m"
			# @returns [Numeric] Timeout in seconds
			def self.parse_timeout(value)
				return nil unless value
				
				amount = value[0...-1].to_i
				unit = value[-1]
				
				case unit
				when "H" then amount * 3600
				when "M" then amount * 60
				when "S" then amount
				when "m" then amount / 1000.0
				when "u" then amount / 1_000_000.0
				when "n" then amount / 1_000_000_000.0
				else nil
				end
			end
		end
	end
end
```

#### 3. `Protocol::GRPC::Header` and Metadata

gRPC-specific header policy and metadata handling:

```ruby
module Protocol
	module GRPC
		module Header
			# Header class for grpc-status (allowed in trailers)
			class Status < Protocol::HTTP::Header::Split
				def self.trailer?
					true
				end
			end
			
			# Header class for grpc-message (allowed in trailers)
			class Message < Protocol::HTTP::Header::Split
				def self.trailer?
					true
				end
			end
			
			# Base class for custom gRPC metadata (allowed in trailers)
			class Metadata < Protocol::HTTP::Header::Split
				def self.trailer?
					true
				end
			end
		end
		
		# Custom header policy for gRPC
		# Extends Protocol::HTTP::Headers::POLICY with gRPC-specific headers
		HEADER_POLICY = Protocol::HTTP::Headers::POLICY.merge(
			"grpc-status" => Header::Status,
			"grpc-message" => Header::Message,
			# By default, all other headers follow standard HTTP policy
			# But gRPC allows most metadata to be sent as trailers
		).freeze
		
		module Metadata
			# Extract gRPC status from headers
			# Note: In Protocol::HTTP::Headers, trailers are merged into the headers
			# so users just access headers["grpc-status"] regardless of whether it
			# was sent as an initial header or trailer.
			#
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [Integer] Status code (0-16)
			def self.extract_status(headers)
				status = headers["grpc-status"]
				status ? status.to_i : Status::UNKNOWN
			end
			
			# Extract gRPC status message from headers
			# @parameter headers [Protocol::HTTP::Headers]
			# @returns [String, nil] Status message
			def self.extract_message(headers)
				message = headers["grpc-message"]
				message ? URI.decode_www_form_component(message) : nil
			end
			
		# Add gRPC status, message, and optional backtrace to headers.
		# Whether these become headers or trailers is controlled by the protocol layer.
		# @parameter headers [Protocol::HTTP::Headers]
		# @parameter status [Integer] gRPC status code
		# @parameter message [String | Nil] Optional status message
		# @parameter error [Exception | Nil] Optional error object (used to extract backtrace)
		def self.add_status!(headers, status: Status::OK, message: nil, error: nil)
			headers["grpc-status"] = Header::Status.new(status)
			headers["grpc-message"] = Header::Message.new(Header::Message.encode(message)) if message
			
			# Add backtrace from error if available
			if error && error.backtrace && !error.backtrace.empty?
				headers["backtrace"] = error.backtrace
			end
		end
		end
	end
end
```

#### 4. `Protocol::GRPC::Body::Readable`

Reads length-prefixed gRPC messages.

**Design Note:** Since gRPC always uses message framing (never raw HTTP body), we name this `Readable` not `Message`. This is the standard body type for gRPC responses.

```ruby
module Protocol
	module GRPC
		module Body
			# Reads length-prefixed gRPC messages from an HTTP body
			# This is the standard readable body for gRPC - all gRPC responses use message framing
			class Readable < Protocol::HTTP::Body::Wrapper
				# @parameter body [Protocol::HTTP::Body::Readable] The underlying HTTP body
				# @parameter message_class [Class, nil] Protobuf message class with .decode method
				#   If nil, returns raw binary data (useful for channel adapters)
				# @parameter encoding [String, nil] Compression encoding (from grpc-encoding header)
				def initialize(body, message_class: nil, encoding: nil)
					super(body)
					@message_class = message_class
					@encoding = encoding
					@buffer = String.new.force_encoding(Encoding::BINARY)
				end
				
				# Override read to return decoded messages instead of raw chunks
				# This makes the wrapper transparent - users call .read and get messages
				# @returns [Object | String | Nil] Decoded message, raw binary, or nil if stream ended
				def read
					# Read 5-byte prefix: 1 byte compression flag + 4 bytes length
					prefix = read_exactly(5)
					return nil unless prefix
					
					compressed = prefix[0].unpack1("C") == 1
					length = prefix[1..4].unpack1("N")
					
					# Read the message body
					data = read_exactly(length)
					return nil unless data
					
					# Decompress if needed
					data = decompress(data) if compressed
					
					# Decode using message class if provided, otherwise return binary
					# This allows binary mode for channel adapters
					if @message_class
						MessageHelpers.decode(@message_class, data)
					else
						data  # Return raw binary
					end
				end
				
				# Standard Protocol::HTTP::Body::Readable#each now iterates messages
				# No need for separate each_message method
				# Inherited from Readable:
				# def each
				#   return to_enum unless block_given?
				#   
				#   begin
				#     while message = self.read
				#       yield message
				#     end
				#   rescue => error
				#     raise
				#   ensure
				#     self.close(error)
				#   end
				# end
				
				private
				
				def read_exactly(n)
					while @buffer.bytesize < n
						chunk = @body.read
						return nil unless chunk
						@buffer << chunk
					end
					
					data = @buffer[0...n]
					@buffer = @buffer[n..-1]
					data
				end
				
				def decompress(data)
					# TODO: Implement gzip decompression
					data
				end
				
				def close(error = nil)
					@body&.close(error)
				end
			end
			
			# Writes length-prefixed gRPC messages
			# This is the standard writable body for gRPC - all gRPC requests use message framing
			class Writable < Protocol::HTTP::Body::Writable
				# @parameter encoding [String, nil] Compression encoding (gzip, deflate, identity)
				# @parameter level [Integer] Compression level if encoding is used
				def initialize(encoding: nil, level: Zlib::DEFAULT_COMPRESSION, **options)
					super(**options)
					@encoding = encoding
					@level = level
				end
				
				attr :encoding
				
				# Write a message with gRPC framing
				# @parameter message [Object, String] Protobuf message instance or raw binary data
				# @parameter compressed [Boolean] Whether to compress this specific message
				def write(message, compressed: nil)
					# Encode message to binary if it's not already a string
					# This supports both high-level (protobuf objects) and low-level (binary) usage
					data = if message.is_a?(String)
						message  # Already binary, use as-is (for channel adapters)
					else
						MessageHelpers.encode(message)  # Encode protobuf object
					end
					
					# Determine if we should compress this message
					# If compressed param is nil, use the encoding setting
					should_compress = compressed.nil? ? (@encoding && @encoding != "identity") : compressed
					
					# Compress if requested
					data = compress(data) if should_compress
					
					# Build prefix: compression flag + length
					compression_flag = should_compress ? 1 : 0
					length = data.bytesize
					prefix = [compression_flag].pack("C") + [length].pack("N")
					
					# Write prefix + data to underlying body
					super(prefix + data)  # Call Protocol::HTTP::Body::Writable#write
				end
				
								protected
				
				def compress(data)
					case @encoding
					when "gzip"
						require "zlib"
						io = StringIO.new
						gz = Zlib::GzipWriter.new(io, @level)
						gz.write(data)
						gz.close
						io.string
					when "deflate"
						require "zlib"
						Zlib::Deflate.deflate(data, @level)
					else
						data  # No compression or identity
					end
				end
			end
		end
	end
end
```

#### 5. `Protocol::GRPC::Status`

gRPC status codes (as constants):

```ruby
module Protocol
	module GRPC
		module Status
			OK = 0
			CANCELLED = 1
			UNKNOWN = 2
			INVALID_ARGUMENT = 3
			DEADLINE_EXCEEDED = 4
			NOT_FOUND = 5
			ALREADY_EXISTS = 6
			PERMISSION_DENIED = 7
			RESOURCE_EXHAUSTED = 8
			FAILED_PRECONDITION = 9
			ABORTED = 10
			OUT_OF_RANGE = 11
			UNIMPLEMENTED = 12
			INTERNAL = 13
			UNAVAILABLE = 14
			DATA_LOSS = 15
			UNAUTHENTICATED = 16
			
			# Status code descriptions
			DESCRIPTIONS = {
				OK => "OK",
				CANCELLED => "Cancelled",
				UNKNOWN => "Unknown",
				INVALID_ARGUMENT => "Invalid Argument",
				DEADLINE_EXCEEDED => "Deadline Exceeded",
				NOT_FOUND => "Not Found",
				ALREADY_EXISTS => "Already Exists",
				PERMISSION_DENIED => "Permission Denied",
				RESOURCE_EXHAUSTED => "Resource Exhausted",
				FAILED_PRECONDITION => "Failed Precondition",
				ABORTED => "Aborted",
				OUT_OF_RANGE => "Out of Range",
				UNIMPLEMENTED => "Unimplemented",
				INTERNAL => "Internal",
				UNAVAILABLE => "Unavailable",
				DATA_LOSS => "Data Loss",
				UNAUTHENTICATED => "Unauthenticated"
			}.freeze
		end
	end
end
```

#### 6. `Protocol::GRPC::Call`

Represents a single RPC call with metadata and deadline tracking:

```ruby
module Protocol
	module GRPC
		# Represents context for a single RPC call
		class Call
			# @parameter request [Protocol::HTTP::Request] The HTTP request
			# @parameter deadline [Time, nil] Absolute deadline for the call
			def initialize(request, deadline: nil)
				@request = request
				@deadline = deadline
				@cancelled = false
			end
			
			# @attribute [Protocol::HTTP::Request] The underlying HTTP request
			attr :request
			
			# @attribute [Time, nil] The deadline for this call
			attr :deadline
			
			# Extract metadata from request headers
			# @returns [Hash] Custom metadata
			def metadata
				@metadata ||= Methods.extract_metadata(@request.headers)
			end
			
			# Check if the deadline has expired
			# @returns [Boolean]
			def deadline_exceeded?
				@deadline && Time.now > @deadline
			end
			
			# Time remaining until deadline
			# @returns [Numeric, nil] Seconds remaining, or nil if no deadline
			def time_remaining
				@deadline ? [@deadline - Time.now, 0].max : nil
			end
			
			# Mark this call as cancelled
			def cancel!
				@cancelled = true
			end
			
			# Check if call was cancelled
			# @returns [Boolean]
			def cancelled?
				@cancelled
			end
			
			# Get peer information (client address)
			# @returns [String, nil]
			def peer
				@request.peer&.to_s
			end
		end
	end
end
```

#### 7. `Protocol::GRPC::Error`

Exception hierarchy for gRPC errors:

```ruby
module Protocol
	module GRPC
		class Error < StandardError
			attr_reader :status_code, :details, :metadata
			
			def initialize(status_code, message = nil, details: nil, metadata: {})
				@status_code = status_code
				@details = details
				@metadata = metadata
				super(message || Status::DESCRIPTIONS[status_code])
			end
		end
		
				# Specific error classes for common status codes
		class Cancelled < Error
			def initialize(message = nil, **options)
				super(Status::CANCELLED, message, **options)
			end
		end
		
		class InvalidArgument < Error
			def initialize(message = nil, **options)
				super(Status::INVALID_ARGUMENT, message, **options)
			end
		end
		
		class DeadlineExceeded < Error
			def initialize(message = nil, **options)
				super(Status::DEADLINE_EXCEEDED, message, **options)
			end
		end
		
		class NotFound < Error
			def initialize(message = nil, **options)
				super(Status::NOT_FOUND, message, **options)
			end
		end
		
		class Internal < Error
			def initialize(message = nil, **options)
				super(Status::INTERNAL, message, **options)
			end
		end
		
		class Unavailable < Error
			def initialize(message = nil, **options)
				super(Status::UNAVAILABLE, message, **options)
			end
		end
		
		class Unauthenticated < Error
			def initialize(message = nil, **options)
				super(Status::UNAUTHENTICATED, message, **options)
			end
		end
	end
end
```

## Compression in gRPC

**Key Difference from HTTP:**
- **HTTP**: Entire body is compressed (`content-encoding: gzip`)
- **gRPC**: Each message is individually compressed (per-message compression flag)
- `grpc-encoding` header indicates the algorithm used
- Each message's byte 0 (compression flag) indicates if that specific message is compressed

**Design Decision:** Since gRPC bodies are ALWAYS message-framed, compression is built into `Readable` and `Writable`. No separate wrapper needed - just pass the `encoding` parameter.

```ruby
# Compression is built-in, controlled by encoding parameter
body = Protocol::GRPC::Body::Writable.new(encoding: "gzip")
body.write(message)  # Automatically compressed with prefix

# Reading automatically decompresses
encoding = response.headers["grpc-encoding"]
body = Protocol::GRPC::Body::Readable.new(
	response.body,
	message_class: MyReply,
	encoding: encoding
)
message = body.read  # Automatically decompressed
```

This is cleaner than Protocol::HTTP's separate `Deflate`/`Inflate` wrappers because:
- gRPC always has message framing (never raw bytes)
- Compression is per-message (part of the framing protocol)
- No need for separate wrapper classes

#### 9. `Protocol::GRPC::Middleware`

Server middleware for handling gRPC requests:

```ruby
module Protocol
	module GRPC
		# Server middleware for handling gRPC requests
		# Implements Protocol::HTTP::Middleware interface
		# This is the protocol-level server - no async, just request/response handling
		class Middleware < Protocol::HTTP::Middleware
			# @parameter app [#call] The next middleware in the chain
			# @parameter services [Hash] Map of service name => service handler
			def initialize(app = nil, services: {})
				super(app)
				@services = services
			end
			
			# Register a service handler
			# @parameter service_name [String] Full service name, e.g., "my_service.Greeter"
			# @parameter handler [Object] Service implementation
			def register(service_name, handler)
				@services[service_name] = handler
			end
			
			# Handle incoming HTTP request
			# @parameter request [Protocol::HTTP::Request]
			# @returns [Protocol::HTTP::Response]
			def call(request)
				# Check if this is a gRPC request
				unless grpc_request?(request)
					# Not a gRPC request, pass to next middleware
					return super
				end
				
				# Parse service and method from path
				service_name, method_name = Methods.parse_path(request.path)
				
				# Find handler
				handler = @services[service_name]
				unless handler
					return make_response(Status::UNIMPLEMENTED, "Service not found: #{service_name}")
				end
				
				# Determine handler method and message classes
				rpc_desc = handler.class.respond_to?(:rpc_descriptions) ? handler.class.rpc_descriptions[method_name] : nil
				
				if rpc_desc
					# Use generated RPC descriptor
					handler_method = rpc_desc[:method]
					request_class = rpc_desc[:request_class]
					response_class = rpc_desc[:response_class]
				else
					# Fallback to simple method name
					handler_method = method_name.underscore.to_sym
					request_class = nil
					response_class = nil
				end
				
				unless handler.respond_to?(handler_method)
					return make_response(Status::UNIMPLEMENTED, "Method not found: #{method_name}")
				end
				
				# Handle the RPC
			begin
				handle_rpc(request, handler, handler_method, request_class, response_class)
			rescue Error => error
				make_response(error.status_code, error.message, error: error)
			rescue => error
				make_response(Status::INTERNAL, error.message, error: error)
			end
			end
			
			protected
			
			def grpc_request?(request)
				content_type = request.headers["content-type"]
				content_type&.start_with?("application/grpc")
			end
			
			# Override in subclass to add async handling
			def handle_rpc(request, handler, method, request_class, response_class)
				# Create input/output streams
				encoding = request.headers["grpc-encoding"]
				input = Body::Readable.new(request.body, message_class: request_class, encoding: encoding)
				output = Body::Writable.new(encoding: encoding)
				
								# Create call context
				response_headers = Protocol::HTTP::Headers.new([], nil, policy: HEADER_POLICY)
				response_headers["content-type"] = "application/grpc+proto"
				response_headers["grpc-encoding"] = encoding if encoding
				
				call = Call.new(request)
				
								# Invoke handler
				handler.send(method, input, output, call)
				output.close_write unless output.closed?
				
							# Mark trailers and add status
			response_headers.trailer!
			Metadata.add_status!(response_headers, status: Status::OK)
			
			Protocol::HTTP::Response[200, response_headers, output]
		end
		
		protected
		
		def make_response(status_code, message, error: nil)
			headers = Protocol::HTTP::Headers.new([], nil, policy: HEADER_POLICY)
			headers["content-type"] = "application/grpc+proto"
			Metadata.add_status!(headers, status: status_code, message: message, error: error)
			
			Protocol::HTTP::Response[200, headers, nil]
		end
		end
	end
end
```

#### 10. `Protocol::GRPC::HealthCheck`

Standard health checking protocol:

```ruby
module Protocol
	module GRPC
		module HealthCheck
						# Health check status constants
			module ServingStatus
				UNKNOWN = 0
				SERVING = 1
				NOT_SERVING = 2
				SERVICE_UNKNOWN = 3
			end
		end
	end
end
```

## Usage Examples

### Building a gRPC Request (Protocol Layer Only)

```ruby
require "protocol/grpc"
require "protocol/http"

# Create request body with protobuf messages
body = Protocol::GRPC::Body::Writable.new
body.write(MyService::HelloRequest.new(name: "World"))
body.close_write

# Build gRPC headers
headers = Protocol::GRPC::Methods.build_headers(
	metadata: {"authorization" => "Bearer token123"},
	timeout: 5.0
)

# Create HTTP request with gRPC path
path = Protocol::GRPC::Methods.build_path("my_service.Greeter", "SayHello")

request = Protocol::HTTP::Request[
	"POST", path,
	headers: headers,
	body: body,
	scheme: "https",
	authority: "localhost:50051"
]

# Request is now ready to be sent via any HTTP/2 client
# (e.g., Async::HTTP::Client, or any other Protocol::HTTP-compatible client)
```

### Reading a gRPC Response (Protocol Layer Only)

```ruby
require "protocol/grpc"

# Assume we got an HTTP response from somewhere
# http_response = client.call(request)

# Read protobuf messages from response body
message_body = Protocol::GRPC::Body::Readable.new(
	http_response.body,
	message_class: MyService::HelloReply
)

# Read single message (unary RPC)
reply = message_body.read
puts reply.message

# Or iterate over multiple messages (server streaming)
message_body.each do |reply|
	puts reply.message
end

# Extract gRPC status from trailers
status = Protocol::GRPC::Metadata.extract_status(http_response.headers)
if status != Protocol::GRPC::Status::OK
	message = Protocol::GRPC::Metadata.extract_message(http_response.headers)
	raise Protocol::GRPC::Error.new(status, message)
end
```

### Server: Handling a gRPC Request (Protocol Layer Only)

```ruby
require "protocol/grpc"

# This would be inside a Rack/HTTP middleware/handler
def handle_grpc_request(http_request)
		# Parse gRPC path
	service, method = Protocol::GRPC::Methods.parse_path(http_request.path)
	
		# Read input messages
	input = Protocol::GRPC::Body::Readable.new(
		http_request.body,
		message_class: MyService::HelloRequest
	)
	
	request_message = input.read
	
		# Process the request
	reply = MyService::HelloReply.new(
		message: "Hello, #{request_message.name}!"
	)
	
		# Create response body
	output = Protocol::GRPC::Body::Writable.new
	output.write(reply)
	output.close_write
	
		# Build response headers with gRPC policy
	headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)
	headers["content-type"] = "application/grpc+proto"
	
		# Mark that trailers will follow (after body)
	headers.trailer!
	
		# Add status as trailer - these will be sent after the response body
		# Note: The user just adds them to headers; the @tail marker ensures
		# they're recognized as trailers internally
	Protocol::GRPC::Metadata.add_status!(headers, status: Protocol::GRPC::Status::OK)
	
	Protocol::HTTP::Response[200, headers, output]
end
```

### Working with Protobuf Messages

```ruby
require "protocol/grpc"
require_relative "my_service_pb"  # Generated by protoc

# Google's protobuf gem generates classes that work automatically:
# - MyService::HelloRequest has .decode(binary) class method
# - message instances have #to_proto instance method

# Check if a class is compatible
Protocol::GRPC::MessageHelpers.protobuf?(MyService::HelloRequest)  # => true

# Encode a message
request = MyService::HelloRequest.new(name: "World")
binary = Protocol::GRPC::MessageHelpers.encode(request)

# Decode a message
decoded = Protocol::GRPC::MessageHelpers.decode(MyService::HelloRequest, binary)

# These helpers allow the protocol layer to work with any protobuf
# implementation that provides .decode and #to_proto / #encode methods
```

### Understanding Trailers in gRPC

```ruby
require "protocol/grpc"

# Example 1: Normal Response (status in trailers)
# Create headers with gRPC policy (required for trailer support)
headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)

# Add initial headers
headers["content-type"] = "application/grpc+proto"
headers["custom-metadata"] = "initial-value"

# Mark the boundary: everything added after this is a trailer
headers.trailer!

# Add trailers (sent after response body)
headers["grpc-status"] = "0"
headers["grpc-message"] = "OK"
headers["custom-trailer"] = "final-value"

# From the user perspective, both headers and trailers are accessed the same way:
headers["content-type"]      # => "application/grpc+proto"
headers["grpc-status"]       # => "0"
headers["custom-trailer"]    # => "final-value"

# But internally, Protocol::HTTP::Headers knows which are trailers:
headers.trailer?             # => true
headers.tail                 # => 2 (index where trailers start)

# Iterate over just the trailers:
headers.trailer.each do |key, value|
	puts "#{key}: #{value}"
end
# Outputs:
# grpc-status: 0
# grpc-message: OK
# custom-trailer: final-value

# The gRPC header policy ensures grpc-status and grpc-message are allowed as trailers
# Without the policy, they would be rejected when added after trailer!()
```

```ruby
# Example 2: Trailers-Only Response (immediate error, status in headers)
# This is used when you have an error before sending any response body

headers = Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)

# Add initial headers
headers["content-type"] = "application/grpc+proto"

# Add status directly as headers (NOT trailers) - no need to call trailer!
headers["grpc-status"] = Protocol::GRPC::Status::NOT_FOUND.to_s
headers["grpc-message"] = URI.encode_www_form_component("User not found")

# No trailer!() call, no body
Protocol::HTTP::Response[200, headers, nil]

# This is a "trailers-only" response - the status is sent immediately
# without any response body. This is semantically equivalent to sending
# trailers, but more efficient when there's no data to send.
```

## Code Generation

`protocol-grpc` includes a simple code generator for service definitions.

### Philosophy

- **Use standard `protoc` for messages**: Don't reinvent Protocol Buffers serialization
- **Generate service layer only**: Parse `.proto` files to extract service definitions
- **Generate Async::GRPC-compatible code**: Client stubs and server base classes
- **Minimal dependencies**: Simple text parsing, no need for full protobuf compiler

### Generator API

```ruby
require "protocol/grpc/generator"

# Generate from .proto file
generator = Protocol::GRPC::Generator.new("my_service.proto")

# Generate client stubs
generator.generate_client("lib/my_service_client.rb")

# Generate server base classes
generator.generate_server("lib/my_service_server.rb")

# Or generate both
generator.generate_all("lib/my_service_grpc.rb")
```

### Example: Input .proto File

```protobuf
syntax = "proto3";

package my_service;

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
}

message Point {
  int32 latitude = 1;
  int32 longitude = 2;
}

message RouteSummary {
  int32 point_count = 1;
}

service Greeter {
  // Unary RPC
  rpc SayHello(HelloRequest) returns (HelloReply);
  
  // Server streaming RPC
  rpc StreamNumbers(HelloRequest) returns (stream HelloReply);
  
  // Client streaming RPC
  rpc RecordRoute(stream Point) returns (RouteSummary);
  
  // Bidirectional streaming RPC
  rpc RouteChat(stream Point) returns (stream Point);
}
```

### Generated Client Stub

```ruby
# Generated by Protocol::GRPC::Generator
# DO NOT EDIT

require "protocol/grpc"
require_relative "my_service_pb"  # Generated by protoc --ruby_out

module MyService
		# Client stub for Greeter service
	class GreeterClient
				# @parameter client [Async::GRPC::Client] The gRPC client
		def initialize(client)
			@client = client
		end
		
		SERVICE_PATH = "my_service.Greeter"
		
				# Unary RPC: SayHello
				# @parameter request [MyService::HelloRequest]
				# @parameter metadata [Hash] Custom metadata
				# @parameter timeout [Numeric] Deadline
				# @returns [MyService::HelloReply]
		def say_hello(request, metadata: {}, timeout: nil)
			@client.unary(
				SERVICE_PATH,
				"SayHello",
				request,
				response_class: MyService::HelloReply,
				metadata: metadata,
				timeout: timeout
			)
		end
		
				# Server streaming RPC: StreamNumbers
				# @parameter request [MyService::HelloRequest]
				# @yields {|response| ...} Each HelloReply message
				# @returns [Enumerator<MyService::HelloReply>] if no block given
		def stream_numbers(request, metadata: {}, timeout: nil, &block)
			@client.server_streaming(
				SERVICE_PATH,
				"StreamNumbers",
				request,
				response_class: MyService::HelloReply,
								metadata: metadata,
								timeout: timeout,
				&block
			)
		end
		
				# Client streaming RPC: RecordRoute
				# @yields {|stream| ...} Block that writes Point messages
				# @returns [MyService::RouteSummary]
		def record_route(metadata: {}, timeout: nil, &block)
			@client.client_streaming(
				SERVICE_PATH,
				"RecordRoute",
				response_class: MyService::RouteSummary,
								metadata: metadata,
								timeout: timeout,
				&block
			)
		end
		
				# Bidirectional streaming RPC: RouteChat
				# @yields {|input, output| ...} input for writing, output for reading
		def route_chat(metadata: {}, timeout: nil, &block)
			@client.bidirectional_streaming(
				SERVICE_PATH,
				"RouteChat",
				response_class: MyService::Point,
								metadata: metadata,
								timeout: timeout,
				&block
			)
		end
	end
end
```

### Generated Server Base Class

```ruby
# Generated by Protocol::GRPC::Generator
# DO NOT EDIT

require "protocol/grpc"
require_relative "my_service_pb"  # Generated by protoc --ruby_out

module MyService
		# Base class for Greeter service implementation
		# Inherit from this class and implement the RPC methods
	class GreeterService
				# Unary RPC: SayHello
				# Override this method in your implementation
				# @parameter request [MyService::HelloRequest]
				# @parameter call [Protocol::GRPC::ServerCall] Call context with metadata
				# @returns [MyService::HelloReply]
		def say_hello(request, call)
			raise NotImplementedError, "#{self.class}#say_hello not implemented"
		end
		
				# Server streaming RPC: StreamNumbers
				# Override this method in your implementation
				# @parameter request [MyService::HelloRequest]
				# @parameter call [Protocol::GRPC::ServerCall] Call context with metadata
				# @yields [MyService::HelloReply] Yield each response message
		def stream_numbers(request, call)
			raise NotImplementedError, "#{self.class}#stream_numbers not implemented"
		end
		
				# Client streaming RPC: RecordRoute
				# Override this method in your implementation
				# @parameter call [Protocol::GRPC::ServerCall] Call context with metadata
				# @yields [MyService::Point] Each request message from client
				# @returns [MyService::RouteSummary]
		def record_route(call)
			raise NotImplementedError, "#{self.class}#record_route not implemented"
		end
		
				# Bidirectional streaming RPC: RouteChat
				# Override this method in your implementation
				# @parameter call [Protocol::GRPC::ServerCall] Call context with metadata
				# @returns [Enumerator, Enumerator] (input, output) - input for reading, output for writing
		def route_chat(call)
			raise NotImplementedError, "#{self.class}#route_chat not implemented"
		end
		
				# Internal: Dispatch method for Async::GRPC::Server
				# Maps RPC calls to handler methods
		def self.rpc_descriptions
			{
				"SayHello" => {
					method: :say_hello,
										request_class: MyService::HelloRequest,
										response_class: MyService::HelloReply,
										request_streaming: false,
										response_streaming: false
				},
								"StreamNumbers" => {
									method: :stream_numbers,
										request_class: MyService::HelloRequest,
										response_class: MyService::HelloReply,
										request_streaming: false,
										response_streaming: true
								},
								"RecordRoute" => {
									method: :record_route,
										request_class: MyService::Point,
										response_class: MyService::RouteSummary,
										request_streaming: true,
										response_streaming: false
								},
								"RouteChat" => {
									method: :route_chat,
										request_class: MyService::Point,
										response_class: MyService::Point,
										request_streaming: true,
										response_streaming: true
								}
			}
		end
	end
end
```

### Usage: Client Side

```ruby
require "async"
require "async/grpc/client"
require_relative "my_service_grpc"

endpoint = Async::HTTP::Endpoint.parse("https://localhost:50051")

Async do
	client = Async::GRPC::Client.new(endpoint)
	stub = MyService::GreeterClient.new(client)
	
		# Clean, typed interface!
	request = MyService::HelloRequest.new(name: "World")
	response = stub.say_hello(request)
	puts response.message
	
		# Server streaming
	stub.stream_numbers(request) do |reply|
		puts reply.message
	end
ensure
	client.close
end
```

### Usage: Server Side

```ruby
require "async"
require "async/grpc/server"
require_relative "my_service_grpc"

# Implement the service by inheriting from generated base class
class MyGreeter < MyService::GreeterService
	def say_hello(request, call)
		MyService::HelloReply.new(
			message: "Hello, #{request.name}!"
		)
	end
	
	def stream_numbers(request, call)
		10.times do |i|
			yield MyService::HelloReply.new(
				message: "Number #{i} for #{request.name}"
			)
		end
	end
	
	def record_route(call)
		points = []
		call.each_request do |point|
			points << point
		end
		
		MyService::RouteSummary.new(
			point_count: points.size
		)
	end
end

# Register service
Async do
	server = Async::GRPC::Server.new
	server.register("my_service.Greeter", MyGreeter.new)
	
		# ... start server
end
```

### Generator Implementation

The generator would:
1. **Parse `.proto` files** using simple regex/text parsing (no full compiler needed)
2. **Extract service definitions**: service name, RPC methods, request/response types
3. **Determine streaming types**: unary, server streaming, client streaming, bidirectional
4. **Generate Ruby code** using ERB templates or string interpolation

Key classes:
```ruby
module Protocol
	module GRPC
		class Generator
						# @parameter proto_file [String] Path to .proto file
			def initialize(proto_file)
				@proto = parse_proto(proto_file)
			end
			
			def generate_client(output_path)
								# Generate client stub
			end
			
			def generate_server(output_path)
								# Generate server base class
			end
			
						private
			
			def parse_proto(file)
								# Simple parsing - extract:
								# - package name
								# - message names (just reference them, protoc generates these)
								# - service definitions
								# - RPC methods with request/response types and streaming flags
			end
		end
	end
end
```

### Workflow

```bash
# Step 1: Generate message classes with standard protoc
protoc --ruby_out=lib my_service.proto

# Step 2: Generate gRPC service layer with protocol-grpc using Bake
bake protocol:grpc:generate my_service.proto

# Or generate from all .proto files in a directory
bake protocol:grpc:generate:all
```

### Bake Tasks

```ruby
# bake/protocol/grpc.rb
module Bake
	module Protocol
		module GRPC
			# Generate gRPC service stubs from .proto file
			# @parameter path [String] Path to .proto file
			def generate(path)
				require "protocol/grpc/generator"
				
				generator = ::Protocol::GRPC::Generator.new(path)
				output_path = path.sub(/\.proto$/, "_grpc.rb")
				
				generator.generate_all(output_path)
				
				Console.logger.info(self){"Generated #{output_path}"}
			end
			
						# Generate gRPC stubs for all .proto files in directory
						# @parameter directory [String] Directory containing .proto files
			def generate_all(directory: ".")
				Dir.glob(File.join(directory, "**/*.proto")).each do |proto_file|
					generate(proto_file)
				end
			end
		end
	end
end
```

Usage:
```bash
# Generate from specific file
bake protocol:grpc:generate sample/my_service.proto

# Generate all in directory
bake protocol:grpc:generate:all

# Or from specific directory
bake protocol:grpc:generate:all directory=protos/
```

This keeps dependencies minimal while providing great developer experience!

## Implementation Roadmap

### Phase 1: Core Protocol Primitives
   - `Protocol::GRPC::Message` interface (✅ Designed)
   - `Protocol::GRPC::MessageHelpers` for encoding/decoding (✅ Designed)
   - `Protocol::GRPC::Status` constants (✅ Designed)
   - `Protocol::GRPC::Error` hierarchy (✅ Designed)
   - `Protocol::GRPC::Body::Readable` (framing reader) (✅ Designed)
   - `Protocol::GRPC::Body::Writable` (framing writer) (✅ Designed)
   - Binary message support (no message_class = raw binary) (✅ Designed)

### Phase 2: Protocol Helpers  
   - `Protocol::GRPC::Methods` (path parsing, header building) (✅ Designed)
   - `Protocol::GRPC::Header` classes (Status, Message, Metadata) (✅ Designed)
   - `Protocol::GRPC::HEADER_POLICY` for trailer support (✅ Designed)
   - `Protocol::GRPC::Metadata` (status extraction, trailer helpers) (✅ Designed)
   - `Protocol::GRPC::Call` context object (✅ Designed)
   - `Protocol::GRPC::Middleware` server (✅ Designed)
   - Compression support (built into Readable/Writable) (✅ Designed)
   - `Protocol::GRPC::HealthCheck` protocol (✅ Designed)
   - Binary metadata support (base64 encoding for `-bin` headers) (✅ Designed)
   - Timeout format handling (✅ Designed)

### Phase 3: Code Generation
   - `Protocol::GRPC::Generator` - Parse .proto files
   - Generate client stubs
   - Generate server base classes
   - CLI tool: `bake protocol:grpc:generate`

### Phase 4: Advanced Protocol Features
   - Compression support (gzip)
   - Streaming body wrappers
   - Message validation helpers

### Phase 5: Separate Gems (Not in protocol-grpc)
   - `async-grpc` - Async client implementation + helpers
     - No server class needed (just use Protocol::GRPC::Middleware with Async::HTTP::Server)
     - Channel adapter for Google Cloud integration

## Design Decisions

### Protocol Layer Only

This gem provides **only protocol abstractions**, not client/server implementations. This follows the same pattern as `protocol-http`:
- `protocol-http` → provides HTTP abstractions
- `protocol-http1` → implements HTTP/1.1 protocol
- `protocol-http2` → implements HTTP/2 protocol  
- `async-http` → provides client/server using the protocols

Similarly:
- `protocol-grpc` → provides gRPC abstractions (this gem)
- `async-grpc` → provides client/server implementations (separate gem)

### Why Build on Protocol::HTTP?

- **Reuse**: gRPC runs over HTTP/2; leverage existing HTTP/2 implementations
- **Separation**: Keep gRPC protocol logic independent from transport concerns
- **Compatibility**: Works with any Protocol::HTTP-compatible implementation
- **Flexibility**: Users can choose their HTTP/2 client/server

### Message Framing

gRPC uses a 5-byte prefix for each message:
- 1 byte: Compression flag (0 = uncompressed, 1 = compressed)
- 4 bytes: Message length (big-endian uint32)

This is handled by `Protocol::GRPC::Body::Readable` and `Writable`, which wrap `Protocol::HTTP::Body` classes.

### Protobuf Interface

The gem defines a simple interface for protobuf messages:
- Class method: `.decode(binary)` - decode binary data to message
- Instance method: `#to_proto` or `#encode` - encode message to binary

Google's `protobuf` gem already provides these methods, so generated classes work without modification. This keeps the protocol layer decoupled from any specific protobuf implementation.

### Status Codes and Trailers

gRPC uses its own status codes (0-16), which can be transmitted in two ways:

**1. Trailers-Only Response** (status in initial headers):
- Used for immediate errors or responses without a body
- `grpc-status` is sent as an initial header
- `grpc-message` is sent as an initial header (if present)
- HTTP status is still 200 (or 4xx/5xx in some cases)
- No response body is sent

**2. Normal Response** (status in trailers):
- Used for successful responses with data
- Response body contains length-prefixed messages
- `grpc-status` is sent as a trailer (after the body)
- `grpc-message` is sent as a trailer if there's an error

**Understanding Protocol::HTTP::Headers Trailers:**

`Protocol::HTTP::Headers` has a `@tail` index that marks where trailers begin in the internal `@fields` array. When you call `headers.trailer!()`, it marks the current position as the start of trailers. Any headers added after that point are trailers.

From the user's perspective:
- Access: `headers["grpc-status"]` works regardless of whether it's a header or trailer
- The `@tail` marker is internal bookkeeping
- Each header type has a `.trailer?` class method that determines if it's allowed in trailers
- By default, most HTTP headers are NOT allowed in trailers

**gRPC Header Policy:**

Protocol::GRPC defines `HEADER_POLICY` that extends `Protocol::HTTP::Headers::POLICY`:
- `grpc-status` → allowed BOTH as initial header AND as trailer
- `grpc-message` → allowed BOTH as initial header AND as trailer
- Custom metadata → can be sent as headers or trailers

The policy uses special header classes that return `.trailer? = true`, allowing them to appear in trailers. They can also appear as regular headers without calling `trailer!()`.

This policy must be passed when creating headers: `Protocol::HTTP::Headers.new([], nil, policy: Protocol::GRPC::HEADER_POLICY)`

### Metadata

Custom metadata is transmitted as HTTP headers:
- Regular metadata: plain headers (e.g., `authorization`)
- Binary metadata: headers ending in `-bin`, base64 encoded
- Reserved headers: `grpc-*`, `content-type`, `te`

### Streaming Models

All four RPC patterns are supported through the protocol primitives:
1. **Unary**: Single message written and read
2. **Server Streaming**: Single write, multiple reads
3. **Client Streaming**: Multiple writes, single read
4. **Bidirectional**: Multiple writes and reads

These map naturally to `Protocol::HTTP::Body::Writable` and `Readable`.

## Missing/Future Features

### Protocol-Level Features (Phase 3+)

1. **Compression Negotiation** (Compression already designed in Phase 2)
   - `grpc-accept-encoding` header parsing (advertise supported encodings)
   - Algorithm selection logic
   - Fallback to identity encoding

2. **Service Descriptor Protocol**
   - Parse `.proto` files into descriptor objects
   - Used by reflection API
   - Service/method metadata

3. **Health Check Protocol**
   - Standard health check message types
   - Health status enum (SERVING, NOT_SERVING, UNKNOWN)
   - Per-service health status

4. **Reflection Protocol Messages**
   - ServerReflectionRequest/Response messages
   - FileDescriptorProto support
   - Service/method listing

5. **Well-Known Error Details**
   - Standard error detail messages
   - `google.rpc.Status` with details
   - `google.rpc.ErrorInfo`, `google.rpc.RetryInfo`, etc.

### Protocol Helpers (Should Add)

6. **Binary Message Support** (✅ Designed)
   - `Body::Readable` and `Writable` work with raw binary when `message_class: nil`
   - No message_class = no decoding, just return binary
   - Needed for channel adapters and gRPC-web

7. **Context/Call Metadata**
   - `Protocol::GRPC::Call` - represents single RPC (✅ Added)
   - Deadline tracking (✅ Added)
   - Cancellation signals (✅ Added)
   - Peer information (✅ Added)

8. **Service Config**
   - Retry policy configuration
   - Timeout configuration
   - Load balancing hints
   - Parse from JSON

9. **Name Resolution**
   - Parse gRPC URIs (dns:///host:port, etc.)
   - Service config discovery

## Open Questions

1. **Compression**: Protocol layer or implementation?
   - Protocol layer could provide `Body::Compressed` wrapper
   - Implementation handles negotiation
   - **Recommendation**: Protocol provides wrappers, implementation handles negotiation

2. **Custom Metadata Policy**: Should all metadata be trailerable?
   - Current: Only `grpc-status` and `grpc-message` marked
   - gRPC allows most metadata in trailers
   - **Need to research**: Which headers MUST be in initial headers?

3. **Binary Metadata**: Auto-encode/decode `-bin` headers?
   - Current design: Yes, automatically base64 encode/decode
   - Transparent for users
   - **Recommendation**: Keep automatic encoding

4. **Message Class vs Decoder**: How to specify decoding?
   - Current: Pass message class, calls `.decode(data)`
   - Alternative: Pass decoder proc
   - **Recommendation**: Keep class-based, simple and clean

5. **Error Hierarchy**: Specific classes or generic?
   - Current: Specific classes per status code
   - Makes rescue clauses cleaner
   - **Recommendation**: Keep specific classes

6. **Service Discovery**: Should protocol-grpc include URI parsing?
   - gRPC URIs: `dns:///host:port`, `unix:///path`, etc.
   - Or leave to async-grpc?
   - **Recommendation**: Basic URI parsing in protocol-grpc

## References

- [gRPC Protocol](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md)
- [Protocol::HTTP Design](https://socketry.github.io/protocol-http/guides/design-overview/)
- [gRPC over HTTP/2](https://grpc.io/docs/what-is-grpc/core-concepts/)

