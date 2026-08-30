class DataRetentionJob < ApplicationJob
  queue_as :maintenance
  BATCH_SIZE = 500
  ORPHANED_BLOB_GRACE_PERIOD = 24.hours

  def perform
    delete_in_batches(Session.where(updated_at: ...session_cutoff))
    delete_in_batches(LoginChallenge.where(created_at: ...LoginChallenge::LIFETIME.ago))
    delete_in_batches(StepUpChallenge.where(created_at: ...StepUpChallenge::GRANT_LIFETIME.ago))
    delete_in_batches(StepUpGrant.where(expires_at: ...Time.current))
    delete_in_batches(AdminApproval.where(expires_at: ...Time.current))
    delete_in_batches(LoginAttempt.where(created_at: ...login_attempt_cutoff))
    delete_in_batches(AuditLog.where(created_at: ...audit_cutoff))
    purge_orphaned_blobs
  end

  private
    def delete_in_batches(scope)
      scope.in_batches(of: BATCH_SIZE).delete_all
    end

    def purge_orphaned_blobs
      ActiveStorage::Blob.unattached.where(created_at: ...ORPHANED_BLOB_GRACE_PERIOD.ago).in_batches(of: 100) do |batch|
        batch.each(&:purge_later)
      end
    end

    def session_cutoff
      Integer(ENV.fetch("SESSION_RETENTION_DAYS", "30"), 10).days.ago
    end

    def audit_cutoff
      Integer(ENV.fetch("AUDIT_LOG_RETENTION_DAYS", "365"), 10).days.ago
    end

    def login_attempt_cutoff
      Integer(ENV.fetch("LOGIN_ATTEMPT_RETENTION_DAYS", "30"), 10).days.ago
    end
end
