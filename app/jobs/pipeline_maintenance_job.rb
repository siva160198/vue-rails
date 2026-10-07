class PipelineMaintenanceJob < ApplicationJob
  queue_as :maintenance
  def perform
    # Durable state repairs a missed enqueue (queue and app use different databases).
    ImportRun.where(status: %w[queued staging processing]).where(updated_at: ...15.minutes.ago).limit(50).each do |run|
      run.with_lock do
        next unless run.updated_at < 15.minutes.ago && run.status.in?(%w[queued staging processing])
        if run.recovery_attempts >= 3
          run.rows.in_batches(of: 50).update_all(payload_ciphertext: nil)
          run.update!(status: "failed", source_ciphertext: nil, failure_code: "CSV_QUEUE_UNAVAILABLE", finished_at: Time.current)
        else
          run.update!(recovery_attempts: run.recovery_attempts + 1)
          ImportPipelineJob.perform_later(run.id)
        end
      end
    end
    IntegrationConnection.where(status: %w[queued syncing retry_wait]).where("next_sync_at <= ?", 15.minutes.ago).limit(50).each do |connection|
      connection.with_lock do
        next unless connection.status.in?(%w[queued syncing retry_wait]) && connection.next_sync_at && connection.next_sync_at < 15.minutes.ago
        if connection.recovery_attempts >= 3
          connection.update!(status: "failed", failure_code: "INTEGRATION_QUEUE_UNAVAILABLE")
        else
          connection.update!(recovery_attempts: connection.recovery_attempts + 1, next_sync_at: Time.current)
          IntegrationSyncJob.perform_later(connection.id)
        end
      end
    end
    cutoff = Integer(ENV.fetch("PIPELINE_RETENTION_DAYS", "7"), 10).days.ago
    ImportRun.where(status: %w[completed failed], finished_at: ...cutoff).in_batches(of: 100).delete_all
    IntegrationItem.where(updated_at: ...cutoff).in_batches(of: 100).delete_all
  end
end
