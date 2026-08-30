require "test_helper"

class Api::V1::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "reports that optional passkeys are disabled without relying-party configuration" do
    post options_api_v1_passkeys_url, params: { current_password: "password" }, as: :json

    assert_response :unprocessable_content
    assert_api_error("WEBAUTHN_DISABLED")
  end

  test "cannot delete another user's passkey" do
    credential = users(:two).webauthn_credentials.create!(external_id: "other-id", public_key: "key", nickname: "Other")

    delete api_v1_passkey_url(credential), as: :json

    assert_response :not_found
    assert_api_error("RESOURCE_NOT_FOUND")
  end

  test "rejects registration options after the per-user passkey limit" do
    previous_rp = ENV["WEBAUTHN_RP_ID"]
    previous_origin = ENV["WEBAUTHN_ORIGIN"]
    previous_limit = ENV["MAX_PASSKEYS_PER_USER"]
    ENV["WEBAUTHN_RP_ID"] = "localhost"
    ENV["WEBAUTHN_ORIGIN"] = "https://localhost"
    ENV["MAX_PASSKEYS_PER_USER"] = "2"
    2.times do |index|
      users(:one).webauthn_credentials.create!(external_id: "credential-#{index}", public_key: "key", nickname: "Key #{index}")
    end

    post options_api_v1_passkeys_url, params: { current_password: "password" }, as: :json

    assert_response :unprocessable_content
    assert_api_error("PASSKEY_LIMIT_REACHED")
  ensure
    ENV["WEBAUTHN_RP_ID"] = previous_rp
    ENV["WEBAUTHN_ORIGIN"] = previous_origin
    ENV["MAX_PASSKEYS_PER_USER"] = previous_limit
  end
end
