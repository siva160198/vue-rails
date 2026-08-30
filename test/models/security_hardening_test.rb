require "test_helper"

class SecurityHardeningTest < ActiveSupport::TestCase
  test "encrypts phone and TOTP secret at rest" do
    user = users(:two)
    user.update!(phone: "+62 812 345", totp_secret: TotpAuthenticator.generate_secret)

    raw = User.connection.select_one("SELECT phone, totp_secret FROM users WHERE id = #{user.id}")
    assert raw.fetch("phone").start_with?(SecurityEncryptor::PREFIX)
    assert raw.fetch("totp_secret").start_with?(SecurityEncryptor::PREFIX)
    assert_equal "+62 812 345", user.reload.phone
  end

  test "rejects reuse of a recent password" do
    user = users(:two)
    user.update!(password: "a-brand-new-password", password_confirmation: "a-brand-new-password")
    user.assign_attributes(password: "password", password_confirmation: "password")

    assert_not user.valid?
    assert user.errors.added?(:password, :reused)
  end

  test "audit entries are immutable through Active Record" do
    entry = AuditLog.record!(action: "security.test", actor: users(:one))
    assert_not entry.update(action: "tampered")
    assert_not entry.destroy
    assert_equal "security.test", entry.reload.action
    assert AuditLog.valid_chain?
  end

  test "audit entries use partitioned integrity chains" do
    first = AuditLog.record!(action: "security.first", actor: users(:one))
    second = AuditLog.record!(action: "security.second", actor: users(:two))

    assert_match(/\Ashard-\d+\z/, first.chain_key)
    assert_match(/\Ashard-\d+\z/, second.chain_key)
    assert_nil first.previous_digest
    assert AuditLog.valid_chain?
  end

  test "admin approvals require a different approver and expire safely" do
    approval = AdminApproval.new(requester: users(:one), action_key: "admin.test", payload_digest: "digest", expires_at: 10.minutes.from_now)
    assert_not approval.approved?
    approval.approver = users(:one)
    assert_not approval.valid?
    assert approval.errors.added?(:approver, :invalid)

    approval.approver = users(:two)
    approval.approved_at = Time.current
    assert approval.valid?
    assert approval.approved?
    approval.expires_at = 1.minute.ago
    assert_not approval.approved?
  end

  test "step-up grants are single-use and purpose-bound" do
    user = users(:one)
    token = StepUpGrant.issue_for!(user, "password_change")
    assert_not StepUpGrant.consume(token, user, "passkey_delete")
    assert StepUpGrant.consume(token, user, "password_change")
    assert_not StepUpGrant.consume(token, user, "password_change")
  end
end
