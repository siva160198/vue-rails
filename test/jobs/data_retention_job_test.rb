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

  test "queues deletion of old unattached blobs but preserves recent blobs" do
    old_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("old"), filename: "old.txt", content_type: "text/plain")
    recent_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("recent"), filename: "recent.txt", content_type: "text/plain")
    old_blob.update_column(:created_at, 2.days.ago)

    DataRetentionJob.perform_now

    assert_not ActiveStorage::Blob.exists?(old_blob.id)
    assert ActiveStorage::Blob.exists?(recent_blob.id)
  end
end
