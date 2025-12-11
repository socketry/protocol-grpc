# Getting Started

This guide explains how to use `protocol-grpc` for building abstract gRPC interfaces.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add protocol-grpc
~~~

## Core Concepts

`protocol-grpc` has several core concepts:

  - A {ruby Protocol::GRPC::Interface} class which defines gRPC service contracts with RPC methods, request/response types, and streaming patterns.
  - A {ruby Protocol::GRPC::Body::ReadableBody} class which handles reading gRPC messages from HTTP request/response bodies with automatic framing and decoding.
  - A {ruby Protocol::GRPC::Body::WritableBody} class which handles writing gRPC messages to HTTP request/response bodies with automatic framing and encoding.
  - A {ruby Protocol::GRPC::Middleware} abstract base class for building gRPC server applications.
  - A {ruby Protocol::GRPC::Call} class which represents the context of a single gRPC RPC call, including deadline tracking.
  - A {ruby Protocol::GRPC::Status} module with gRPC status code constants.
  - A {ruby Protocol::GRPC::Error} hierarchy for gRPC-specific error handling.

## Integration

This gem provides protocol-level abstractions only. To actually send requests over the network, you need an HTTP/2 client/server implementation:

  - [Async::GRPC](https://github.com/socketry/async-grpc) which provides asynchronous client and server implementations.
  - [Async::HTTP](https://github.com/socketry/async-http) which provides HTTP/2 transport with connection pooling and concurrency.

## Usage

### Defining an Interface

{ruby Protocol::GRPC::Interface} defines the contract for gRPC services. RPC method names use PascalCase to match `.proto` files:

``` ruby
require "protocol/grpc/interface"

class GreeterInterface < Protocol::GRPC::Interface
	rpc :SayHello, request_class: Hello::HelloRequest, response_class: Hello::HelloReply
	rpc :SayHelloAgain, request_class: Hello::HelloRequest, response_class: Hello::HelloReply,
						streaming: :server_streaming
end
```

### Building a Request

Build gRPC requests using `Protocol::GRPC::Methods` and `Protocol::GRPC::Body::WritableBody`:

``` ruby
require "protocol/grpc"
require "protocol/grpc/methods"
require "protocol/grpc/body/writable_body"

# Build request body
body = Protocol::GRPC::Body::WritableBody.new(message_class: Hello::HelloRequest)
body.write(Hello::HelloRequest.new(name: "World"))
body.close_write

# Build headers
headers = Protocol::GRPC::Methods.build_headers(timeout: 5.0)
path = Protocol::GRPC::Methods.build_path("hello.Greeter", "SayHello")

# Create HTTP request
request = Protocol::HTTP::Request["POST", path, headers, body]
```

### Reading a Response

Read gRPC responses using `Protocol::GRPC::Body::ReadableBody`:

``` ruby
require "protocol/grpc/body/readable_body"

# Read response body
readable_body = Protocol::GRPC::Body::ReadableBody.new(
		response.body,
		message_class: Hello::HelloReply
)

message = readable_body.read
readable_body.close

# Check gRPC status
status = Protocol::GRPC::Metadata.extract_status(response.headers)
if status != Protocol::GRPC::Status::OK
	message = Protocol::GRPC::Metadata.extract_message(response.headers)
	raise Protocol::GRPC::Error.for(status, message)
end
```

### Server Middleware

Create a server middleware by subclassing `Protocol::GRPC::Middleware`:

``` ruby
require "protocol/grpc/middleware"

class MyMiddleware < Protocol::GRPC::Middleware
	protected
	
	def dispatch(request)
				# Parse service and method from path
		service_name, method_name = Protocol::GRPC::Methods.parse_path(request.path)
		
				# Handle the request and return a response
				# ...
	end
end
```

### Call Context

{ruby Protocol::GRPC::Call} provides context for a gRPC call:

``` ruby
require "protocol/grpc/call"

call = Protocol::GRPC::Call.new(request, deadline: deadline)

# Access request
call.request  # => Protocol::HTTP::Request

# Check deadline
call.deadline.exceeded?  # => false

# Access peer information
call.peer  # => Protocol::HTTP::Address
```
