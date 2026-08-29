require "test_helper"

class Api::V1::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "uploads and removes a validated avatar" do
    avatar = fixture_file_upload(Rails.root.join("public/icon.png"), "image/png")

    patch api_v1_profile_url, params: { avatar: avatar }
    assert_response :success
    assert users(:one).reload.avatar.attached?

    delete api_v1_profile_url, as: :json
    assert_response :no_content
    assert_not users(:one).reload.avatar.attached?
  end

  test "rejects unsupported avatar content" do
    avatar = fixture_file_upload(Rails.root.join("README.md"), "text/plain")
    patch api_v1_profile_url, params: { avatar: avatar }

    assert_response :unprocessable_content
    assert_api_error("VALIDATION_FAILED")
  end

  test "regenerates recovery codes only after password confirmation" do
    post recovery_codes_api_v1_profile_url, params: { password: "password" }, as: :json

    assert_response :success
    assert_equal 8, response.parsed_body.fetch("recovery_codes").size
    assert_equal 8, users(:one).reload.recovery_code_digests.size

    post recovery_codes_api_v1_profile_url, params: { password: "wrong" }, as: :json
    assert_response :unauthorized
    assert_api_error("INVALID_CREDENTIALS")
  end
end
