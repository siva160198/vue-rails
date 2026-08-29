require "test_helper"

class DataRetentionJobTest < ActiveJob::TestCase
  test "removes expired sessions challenges and audit logs" do
    user = users(:one)
    old_session = user.sessions.create!(updated_at: 31.days.ago)
    old_challenge = user.login_challenges.create!(code: "123456", expires_at: 1.day.ago, created_at: 2.days.ago)
    old_log = AuditLog.create!(action: "old", created_at: 366.days.ago)

    DataRetentionJob.perform_now

    assert_not Session.exists?(old_session.id)
    assert_not LoginChallenge.exists?(old_challenge.id)
    assert_not AuditLog.exists?(old_log.id)
  end
end
