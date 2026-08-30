require "test_helper"

class Api::V1::SessionManagementControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @current_session = Current.session
  end

  test "user lists only their own sessions with current marker and pagination" do
    other = @user.sessions.create!(ip_address: "192.0.2.10", user_agent: "Other Browser")
    users(:two).sessions.create!(ip_address: "192.0.2.20", user_agent: "Hidden Browser")

    get api_v1_sessions_url, as: :json

    assert_response :success
    ids = response.parsed_body.fetch("sessions").pluck("id")
    assert_includes ids, @current_session.id
    assert_includes ids, other.id
    assert_equal 2, response.parsed_body.dig("pagination", "total")
    assert response.parsed_body.fetch("sessions").find { |session| session["id"] == @current_session.id }.fetch("current")
  end

  test "user revokes one own session and audit is recorded" do
    target = @user.sessions.create!(ip_address: "192.0.2.10", user_agent: "Other Browser")

    assert_difference("AuditLog.count", 1) do
      delete "/api/v1/sessions/#{target.id}", as: :json
    end

    assert_response :success
    assert_not Session.exists?(target.id)
    assert_equal "session.revoked", AuditLog.last.action
  end

  test "user revokes every other session but keeps the current session" do
    2.times { @user.sessions.create! }

    delete others_api_v1_sessions_path, headers: { "X-Step-Up-Token" => step_up_token_for(@user, "sessions_revoke") }, as: :json

    assert_response :success
    assert_equal 2, response.parsed_body.fetch("removed")
    assert_equal [ @current_session.id ], @user.sessions.reload.pluck(:id)
  end

  test "user cannot revoke another user's session" do
    target = users(:two).sessions.create!

    delete "/api/v1/sessions/#{target.id}", as: :json

    assert_response :not_found
    assert Session.exists?(target.id)
  end

  test "expired session is destroyed and cannot authenticate" do
    @current_session.update!(last_seen_at: Session.idle_timeout.ago - 1.second)

    get api_v1_session_url, as: :json

    assert_response :unauthorized
    assert_not Session.exists?(@current_session.id)
    assert AuditLog.exists?(action: "session.expired", actor: @user)
  end

  test "session list exposes last activity and absolute expiry" do
    get api_v1_sessions_url, as: :json

    item = response.parsed_body.fetch("sessions").find { |session| session.fetch("current") }
    assert item.fetch("last_seen_at")
    assert item.fetch("expires_at")
  end
end
