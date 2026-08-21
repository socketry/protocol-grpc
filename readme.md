# Protocol::GRPC

Provides abstractions for working with the gRPC protocol over HTTP/2.

[![Development Status](https://github.com/socketry/protocol-grpc/workflows/Test/badge.svg)](https://github.com/socketry/protocol-grpc/actions?workflow=Test)

## Features

`protocol-grpc` provides protocol-level abstractions for building gRPC applications:

  - **Protocol-level abstractions** - No networking, no client/server implementations. Focuses on gRPC protocol details.
  - **Message framing** - Handles gRPC's 5-byte length-prefixed message format with compression support.
  - **Status codes and error handling** - Complete gRPC status code support with error hierarchy.
  - **Metadata and trailers** - Full support for gRPC metadata headers and HTTP trailers.
  - **Interface definitions** - Define service contracts using `Protocol::GRPC::Interface` with PascalCase method names matching `.proto` files.
  - **Middleware pattern** - Abstract base class for building gRPC server applications.
  - **Call context** - Track deadlines, metadata, and request context for each RPC call.

Following the same pattern as `protocol-http`, this gem provides only protocol abstractions. Client and server implementations are built on top in separate gems (e.g., `async-grpc`).

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-grpc/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-grpc/guides/getting-started/index) - This guide explains how to use `protocol-grpc` for building abstract gRPC interfaces.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-grpc/releases/index) for all releases.

### v0.14.0

  - **Breaking**: Removed the unused `Protocol::GRPC::Call#cancel!` and `Protocol::GRPC::Call#cancelled?` methods.
  - Added `Protocol::GRPC::Call#status` to report the status assigned to the response.

### v0.13.1

  - **Breaking**: Removed the deprecated `Protocol::GRPC::Methods` module. Use `Protocol::GRPC::Route`, `Protocol::GRPC::Metadata`, and `Protocol::GRPC::Header::Timeout` instead.

### v0.13.0

  - Added `Protocol::GRPC::Route` for building and parsing gRPC request paths.
  - Added `Protocol::GRPC::Metadata.build` and `Protocol::GRPC::Metadata.extract`, replacing the corresponding deprecated `Protocol::GRPC::Methods` helpers.

### v0.12.0

  - Added `Protocol::GRPC::Call#timeout` to expose the client-supplied gRPC timeout in seconds.
  - Added `Protocol::GRPC::Header::Timeout.format` and deprecated `Protocol::GRPC::Methods.format_timeout` and `Protocol::GRPC::Methods.parse_timeout`.

### v0.11.0

  - Rename `add_status!` to `assign_status!` to better reflect its purpose of assigning status information to headers or trailers.

### v0.5.0

  - Server-side errors now automatically include backtraces in response headers when an error object is provided. Backtraces are transmitted as arrays via Split headers and can be extracted by clients.
  - Consolidated `add_status_trailer!`, `add_status_header!`, `build_status_headers`, `prepare_trailers!`, and `build_trailers_only_response` into a single `add_status!` method. Whether status becomes headers or trailers is now controlled by the protocol layer.
  - Renamed `trailers_only_error` to `make_response` and inlined response creation logic. The method now accepts an `error:` parameter for automatic backtrace extraction.

### v0.4.0

  - Add `RPC#name`.

### v0.3.0

  - **Breaking**: `Protocol::GRPC::Call` now takes a `response` object parameter instead of separate `response_headers`.
  - **Breaking**: Removed `Call#response_headers` method. Use `call.response.headers` directly.
  - Added `RPC#streaming?` method to check if an RPC is streaming.

### v0.2.0

  - `RPC#method` is always defined (snake case).

### v0.1.0

  - Initial design.

## See Also

  - [async-grpc](https://github.com/socketry/async-grpc) — Asynchronous gRPC client and server implementation using this interface.
  - [protocol-http](https://github.com/socketry/protocol-http) — HTTP protocol abstractions that gRPC builds upon.
  - [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client and server, supporting HTTP/2 which gRPC requires.

## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` shell
bundle exec sus
```

### Making Releases

To make a new release:

``` shell
bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
