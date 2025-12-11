# Releases

## v0.3.0

  - **Breaking**: `Protocol::GRPC::Call` now takes a `response` object parameter instead of separate `response_headers`.
  - **Breaking**: Removed `Call#response_headers` method. Use `call.response.headers` directly.
  - Added `RPC#streaming?` method to check if an RPC is streaming.

## v0.2.0

  - `RPC#method` is always defined (snake case).

## v0.1.0

  - Initial design.
