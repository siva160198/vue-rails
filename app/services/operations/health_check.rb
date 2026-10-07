module Operations
  class HealthCheck
    def call
      checks = {}
      checks[:database] = ActiveRecord::Base.connection.select_value("SELECT 1").to_i == 1
      checks[:workers] = SolidQueue::Process.where(last_heartbeat_at: 2.minutes.ago..).exists?
      oldest = SolidQueue::ReadyExecution.minimum(:created_at)
      checks[:queue_latency] = oldest.nil? || oldest >= Integer(ENV.fetch("QUEUE_MAX_LATENCY_SECONDS", "300"), 10).seconds.ago
      checks[:failed_jobs] = !SolidQueue::FailedExecution.limit(1).exists?
      if ENV["BACKUP_STATUS_FILE"].present?
        status = JSON.parse(File.read(ENV.fetch("BACKUP_STATUS_FILE"), 4096))
        cutoff = Integer(ENV.fetch("BACKUP_MAX_AGE_HOURS", "26"), 10).hours.ago
        checks[:backup_age] = Time.iso8601(status.fetch("local_completed_at")) >= cutoff
        checks[:offsite_backup_age] = Time.iso8601(status.fetch("offsite_completed_at")) >= cutoff if ENV["OFFSITE_BACKUP_BUCKET"].present?
      else
        checks[:backup_age] = false
      end
      { healthy: checks.values.all?, checks: checks }
    rescue ActiveRecord::ActiveRecordError, SystemCallError, JSON::ParserError, KeyError, ArgumentError
      { healthy: false, checks: checks.merge(probe_error: false) }
    end
  end
end
