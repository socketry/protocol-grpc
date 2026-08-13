# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/grpc/error"
require "protocol/grpc/status"

describe Protocol::GRPC::Error do
	let(:status_code) {Protocol::GRPC::Status::INTERNAL}
	let(:message) {"Something went wrong"}
	let(:error) {subject.new(status_code, message)}
	
	it "has status code" do
		expect(error.status_code).to be == status_code
	end
	
	it "has message" do
		expect(error.message).to be == message
	end
	
	it "uses default message from status descriptions" do
		error = subject.new(Protocol::GRPC::Status::OK)
		expect(error.message).to be == "OK"
	end
	
	with "details and metadata" do
		let(:details) {"Additional details"}
		let(:metadata) {{ "key" => "value" }}
		let(:error) {subject.new(status_code, message, details: details, metadata: metadata)}
		
		it "has details" do
			expect(error.details).to be == details
		end
		
		it "has metadata" do
			expect(error.metadata).to be == metadata
		end
	end
	
	with "Cancelled" do
		it "has correct status code" do
			error = Protocol::GRPC::Cancelled.new("Cancelled by user")
			expect(error.status_code).to be == Protocol::GRPC::Status::CANCELLED
		end
	end
	
	with "InvalidArgument" do
		it "has correct status code" do
			error = Protocol::GRPC::InvalidArgument.new("Invalid input")
			expect(error.status_code).to be == Protocol::GRPC::Status::INVALID_ARGUMENT
		end
	end
	
	with "DeadlineExceeded" do
		it "has correct status code" do
			error = Protocol::GRPC::DeadlineExceeded.new("Timeout")
			expect(error.status_code).to be == Protocol::GRPC::Status::DEADLINE_EXCEEDED
		end
	end
	
	with "NotFound" do
		it "has correct status code" do
			error = Protocol::GRPC::NotFound.new("Not found")
			expect(error.status_code).to be == Protocol::GRPC::Status::NOT_FOUND
		end
	end
	
	with "Internal" do
		it "has correct status code" do
			error = Protocol::GRPC::Internal.new("Internal error")
			expect(error.status_code).to be == Protocol::GRPC::Status::INTERNAL
		end
	end
	
	with "Unavailable" do
		it "has correct status code" do
			error = Protocol::GRPC::Unavailable.new("Service unavailable")
			expect(error.status_code).to be == Protocol::GRPC::Status::UNAVAILABLE
		end
	end
	
	with "Unauthenticated" do
		it "has correct status code" do
			error = Protocol::GRPC::Unauthenticated.new("Authentication required")
			expect(error.status_code).to be == Protocol::GRPC::Status::UNAUTHENTICATED
		end
	end
	
	with ".error_class_for_status" do
		it "maps status codes to specialized error classes" do
			expected_classes = {
				Protocol::GRPC::Status::CANCELLED => Protocol::GRPC::Cancelled,
				Protocol::GRPC::Status::INVALID_ARGUMENT => Protocol::GRPC::InvalidArgument,
				Protocol::GRPC::Status::DEADLINE_EXCEEDED => Protocol::GRPC::DeadlineExceeded,
				Protocol::GRPC::Status::NOT_FOUND => Protocol::GRPC::NotFound,
				Protocol::GRPC::Status::INTERNAL => Protocol::GRPC::Internal,
				Protocol::GRPC::Status::UNAVAILABLE => Protocol::GRPC::Unavailable,
				Protocol::GRPC::Status::UNAUTHENTICATED => Protocol::GRPC::Unauthenticated,
			}
			
			expected_classes.each do |status_code, error_class|
				expect(subject.error_class_for_status(status_code)).to be == error_class
			end
		end
		
		it "uses the base error class for other status codes" do
			expect(subject.error_class_for_status(Protocol::GRPC::Status::UNKNOWN)).to be == subject
		end
	end
	
	with ".for" do
		it "creates a specialized error" do
			error = subject.for(Protocol::GRPC::Status::NOT_FOUND, "Missing", metadata: {"key" => "value"})
			
			expect(error).to be_a(Protocol::GRPC::NotFound)
			expect(error.message).to be == "Missing"
			expect(error.metadata).to be == {"key" => "value"}
		end
		
		it "creates a base error for an unmapped status" do
			error = subject.for(Protocol::GRPC::Status::UNKNOWN)
			
			expect(error.class).to be == subject
			expect(error.status_code).to be == Protocol::GRPC::Status::UNKNOWN
		end
	end
end
