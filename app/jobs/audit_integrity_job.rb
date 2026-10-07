class AuditIntegrityJob < ApplicationJob
  queue_as :maintenance
  def perform
    return unless ENV.fetch("AUDIT_INTEGRITY_CHECK_ENABLED", "false") == "true"
    return if AuditLog.valid_chain?
    Rails.logger.error({ event: "operational_alert", code: "AUDIT_INTEGRITY_FAILURE" }.to_json)
  end
end
