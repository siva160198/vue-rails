require "test_helper"

class StructuredLogFormatterTest < ActiveSupport::TestCase
  test "formats tagged messages as JSON with request id" do
    output = StructuredLogFormatter.new.call("INFO", Time.utc(2026, 8, 29), nil, "[request-123] Completed 200 OK")
    payload = JSON.parse(output)

    assert_equal "request-123", payload.fetch("request_id")
    assert_equal "Completed 200 OK", payload.fetch("message")
    assert_equal "INFO", payload.fetch("severity")
  end
end
