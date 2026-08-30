require "test_helper"

class Api::V1::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "shows only the current user's profile" do
    get api_v1_profile_url, as: :json

    assert_response :success
    profile = response.parsed_body.fetch("profile")
    assert_equal users(:one).email_address, profile.fetch("email_address")
    assert_equal users(:one).role, profile.fetch("role")
    assert profile.key?("avatar_url")
  end

  test "uploads and removes a validated avatar" do
    avatar = fixture_file_upload(Rails.root.join("public/icon.png"), "image/png")

    patch api_v1_profile_url, params: { avatar: avatar }
    assert_response :success
    assert users(:one).reload.avatar.attached?
    assert_equal "image/avif", users(:one).avatar.content_type
    assert_operator users(:one).avatar.byte_size, :<=, 50.kilobytes
    decoded = Vips::Image.new_from_buffer(users(:one).avatar.download, "")
    assert_operator decoded.width, :<=, 512
    assert_equal decoded.width, decoded.height

    delete api_v1_profile_url, as: :json
    assert_response :no_content
    assert_not users(:one).reload.avatar.attached?
  end

  test "rejects unsupported avatar content" do
    avatar = fixture_file_upload(Rails.root.join("README.md"), "text/plain")
    patch api_v1_profile_url, params: { avatar: avatar }

    assert_response :unprocessable_content
    assert_api_error("INVALID_AVATAR")
  end

  test "updates personal information and skips unchanged writes" do
    assert_difference("AuditLog.count", 1) do
      patch api_v1_profile_url, params: { first_name: "Siva", last_name: "Kumar", phone: "+62 812-3456" }, as: :json
    end
    assert_response :success
    assert_equal "Siva", users(:one).reload.first_name
    assert_equal false, response.parsed_body.fetch("unchanged")

    assert_no_difference("AuditLog.count") do
      patch api_v1_profile_url, params: { first_name: "Siva", last_name: "Kumar", phone: "+62 812-3456" }, as: :json
    end
    assert_response :success
    assert_equal true, response.parsed_body.fetch("unchanged")
  end
end
