require "test_helper"

class TrustedDeviceTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
    @device, @token, @binding = TrustedDevice.issue!(@user, user_agent: "Test browser")
  end

  test "requires both cookies and the same browser and rotates token once" do
    assert_nil consume(binding: "wrong")
    # Invalid binding permanently expires a token; issue a fresh trust.
    @device, @token, @binding = TrustedDevice.issue!(@user, user_agent: "Test browser")
    assert_nil TrustedDevice.consume!(@user, token: nil, binding: @binding, user_agent: "Test browser")
    result = consume
    assert_equal @device.id, result.first.id
    assert_not_equal @token, result.last
    assert_not_equal @token, @device.reload.token_digest
    assert_nil consume
  end

  test "expires after 30 days and is not extended by use" do
    expiry = @device.expires_at
    travel 29.days do
      assert consume
      assert_equal expiry, @device.reload.expires_at
    end
    travel 31.days do
      assert_nil TrustedDevice.consume!(@user, token: @token, binding: @binding, user_agent: "Test browser")
    end
  end

  test "credential and access changes permanently invalidate trust" do
    @user.increment!(:authentication_version)
    assert_nil consume
    assert_operator @device.reload.expires_at, :<=, Time.current
  end

  test "mandatory MFA and changed user agent cannot bypass verification" do
    assert_not @device.valid_binding?(user: @user, binding: @binding, user_agent: "Other browser")
    @user.update!(role: "admin")
    assert_nil consume
    assert_not @device.valid_binding?(user: @user, binding: @binding, user_agent: "Other browser")
  end

  test "password and MFA credential changes expire device trust" do
    @user.update!(password: "new-test-password-2026")
    assert_operator @device.reload.expires_at, :<=, Time.current
    @device, = TrustedDevice.issue!(@user, user_agent: "Test browser")
    @user.webauthn_credentials.create!(external_id: "test-new-key", public_key: "test-public-key", nickname: "Test")
    assert_operator @device.reload.expires_at, :<=, Time.current
  end

  test "revoking device removes its bound sessions and bounds trust records" do
    session = @user.sessions.create!(trusted_device: @device)
    @device.destroy!
    assert_not Session.exists?(session.id)
    11.times { TrustedDevice.issue!(@user, user_agent: "Test browser") }
    assert_equal 10, @user.trusted_devices.count
  end

  test "database deletion cannot turn a trusted session into an unbound session" do
    session = @user.sessions.create!(trusted_device: @device)
    @device.delete
    assert_not Session.exists?(session.id)
  end

  private
    def consume(binding: @binding)
      TrustedDevice.consume!(@user, token: @token, binding: binding, user_agent: "Test browser")
    end
end
