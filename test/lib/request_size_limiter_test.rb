require "test_helper"
require "stringio"

class RequestSizeLimiterTest < ActiveSupport::TestCase
  def call(path:, length:, content_type: "application/json", language: "en")
    app = ->(_env) { [ 200, {}, [ "ok" ] ] }
    RequestSizeLimiter.new(app).call(
      "PATH_INFO" => path, "REQUEST_METHOD" => "POST", "CONTENT_TYPE" => content_type,
      "CONTENT_LENGTH" => length.to_s, "HTTP_ACCEPT_LANGUAGE" => language
    )
  end

  test "rejects oversized JSON with the standard localized error contract" do
    status, _headers, body = call(path: "/api/v1/session", length: 2.megabytes)
    error = JSON.parse(body.join).fetch("error")
    assert_equal 413, status
    assert_equal "PAYLOAD_TOO_LARGE", error.fetch("code")
    assert_equal({}, error.fetch("details"))
    assert_equal "The request exceeds the allowed size.", error.fetch("message")
  end

  test "allows the bounded multipart avatar allowance" do
    app = ->(_env) { [ 200, {}, [ "ok" ] ] }
    status, = RequestSizeLimiter.new(app).call(
      "PATH_INFO" => "/api/v1/profile", "REQUEST_METHOD" => "PATCH",
      "CONTENT_TYPE" => "multipart/form-data; boundary=test", "CONTENT_LENGTH" => 11.megabytes.to_s
    )
    assert_equal 200, status
  end

  test "rejects an oversized streamed body without a content length" do
    app = lambda do |env|
      env.fetch("rack.input").read
      [ 200, {}, [ "ok" ] ]
    end
    body = StringIO.new("x" * (RequestSizeLimiter::JSON_LIMIT + 1))

    status, _headers, response_body = RequestSizeLimiter.new(app).call(
      "PATH_INFO" => "/api/v1/session", "REQUEST_METHOD" => "POST",
      "CONTENT_TYPE" => "application/json", "rack.input" => body,
      "HTTP_TRANSFER_ENCODING" => "chunked", "HTTP_ACCEPT_LANGUAGE" => "id"
    )

    assert_equal 413, status
    assert_equal "PAYLOAD_TOO_LARGE", JSON.parse(response_body.join).dig("error", "code")
  end

  test "allows a streamed body within the limit" do
    app = lambda do |env|
      assert_equal "bounded", env.fetch("rack.input").read
      [ 200, {}, [ "ok" ] ]
    end

    status, = RequestSizeLimiter.new(app).call(
      "PATH_INFO" => "/api/v1/session", "REQUEST_METHOD" => "POST",
      "CONTENT_TYPE" => "application/json", "rack.input" => StringIO.new("bounded")
    )
    assert_equal 200, status
  end
end
