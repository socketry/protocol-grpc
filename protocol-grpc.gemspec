# frozen_string_literal: true

require_relative "lib/protocol/grpc/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-grpc"
	spec.version = Protocol::GRPC::VERSION
	
	spec.summary = "Protocol abstractions for gRPC, built on top of protocol-http."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/protocol-grpc"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/protocol-grpc/",
		"source_code_uri" => "https://github.com/socketry/protocol-grpc.git",
	}
	
	spec.files = Dir.glob(["{context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "async", "~> 2"
	spec.add_dependency "base64"
	spec.add_dependency "google-protobuf", "~> 4.0"
	spec.add_dependency "protocol-http", "~> 0.56"
end
