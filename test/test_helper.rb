require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  coverage_dir "tmp/coverage"
  minimum_coverage line: 80, branch: 60 if ENV["CI"] || ENV["COVERAGE"]
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def assert_api_error(code, message: nil)
      error = response.parsed_body.fetch("error")
      assert_equal %w[code details message], error.keys.sort
      assert_equal code, error.fetch("code")
      assert_kind_of String, error.fetch("message")
      assert_kind_of Hash, error.fetch("details")
      assert_equal message, error.fetch("message") if message
    end
  end
end
