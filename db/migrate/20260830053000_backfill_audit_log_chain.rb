class BackfillAuditLogChain < ActiveRecord::Migration[8.1]
  def up
    previous = nil
    AuditLog.reset_column_information
    AuditLog.order(:id).find_each do |entry|
      attributes = entry.attributes.symbolize_keys.slice(:action, :metadata, :ip_address, :user_agent, :created_at, :updated_at, :actor_id, :auditable_type, :auditable_id).merge(previous_digest: previous)
      payload = AuditLog.send(:digest_payload, attributes)
      digest = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("audit-log-chain", 32), payload)
      entry.update_columns(previous_digest: previous, entry_digest: digest)
      previous = digest
    end
  end

  def down
    AuditLog.update_all(previous_digest: nil, entry_digest: nil)
  end
end
