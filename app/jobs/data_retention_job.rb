class DataRetentionJob < ApplicationJob
  queue_as :maintenance

  def perform
    Session.where(updated_at: ...session_cutoff).delete_all
    LoginChallenge.where(created_at: ...LoginChallenge::LIFETIME.ago).delete_all
    StepUpChallenge.where(created_at: ...StepUpChallenge::GRANT_LIFETIME.ago).delete_all
    StepUpGrant.where(expires_at: ...Time.current).delete_all
    AdminApproval.where(expires_at: ...Time.current).delete_all
    LoginAttempt.where(created_at: ...30.days.ago).delete_all
    AuditLog.where(created_at: ...audit_cutoff).in_batches.delete_all
  end

  private
    def session_cutoff
      Integer(ENV.fetch("SESSION_RETENTION_DAYS", "30"), 10).days.ago
    end

    def audit_cutoff
      Integer(ENV.fetch("AUDIT_LOG_RETENTION_DAYS", "365"), 10).days.ago
    end
end
