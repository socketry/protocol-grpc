# Releases

## v0.12.0

  - Added `Protocol::GRPC::Call#timeout` to expose the client-supplied gRPC timeout in seconds.
  - Added `Protocol::GRPC::Header::Timeout.format` and deprecated `Protocol::GRPC::Methods.format_timeout` and `Protocol::GRPC::Methods.parse_timeout`.

## v0.11.0

  - Rename `add_status!` to `assign_status!` to better reflect its purpose of assigning status information to headers or trailers.

## v0.5.0

  - Server-side errors now automatically include backtraces in response headers when an error object is provided. Backtraces are transmitted as arrays via Split headers and can be extracted by clients.
  - Consolidated `add_status_trailer!`, `add_status_header!`, `build_status_headers`, `prepare_trailers!`, and `build_trailers_only_response` into a single `add_status!` method. Whether status becomes headers or trailers is now controlled by the protocol layer.
  - Renamed `trailers_only_error` to `make_response` and inlined response creation logic. The method now accepts an `error:` parameter for automatic backtrace extraction.

## v0.4.0

  - Add `RPC#name`.

## v0.3.0

  - **Breaking**: `Protocol::GRPC::Call` now takes a `response` object parameter instead of separate `response_headers`.
  - **Breaking**: Removed `Call#response_headers` method. Use `call.response.headers` directly.
  - Added `RPC#streaming?` method to check if an RPC is streaming.

## v0.2.0

  - `RPC#method` is always defined (snake case).

## v0.1.0

  - Initial design.
