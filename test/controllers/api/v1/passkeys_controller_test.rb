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
end
