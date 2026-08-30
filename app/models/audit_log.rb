class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def self.record!(action:, actor: nil, auditable: nil, metadata: {}, request: nil)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(86420260830)")
      previous = lock.order(:id).last&.entry_digest
      occurred_at = Time.current
      attributes = {
        action: action, actor: actor, auditable: auditable, metadata: metadata,
        ip_address: request&.remote_ip, user_agent: request&.user_agent,
        previous_digest: previous, created_at: occurred_at, updated_at: occurred_at
      }
      canonical = digest_payload(attributes.merge(actor_id: actor&.id, auditable_type: auditable&.class&.base_class&.name, auditable_id: auditable&.id).except(:actor, :auditable))
      create!(**attributes, entry_digest: OpenSSL::HMAC.hexdigest("SHA256", audit_key, canonical)).tap do |entry|
        Rails.logger.info({ event: "security_audit", audit_id: entry.id, action: entry.action, entry_digest: entry.entry_digest }.to_json)
      end
    end
  end

  def self.valid_chain?(scope = order(:id))
    previous = nil
    scope.each_with_index.all? do |entry, index|
      link_valid = index.zero? || entry.previous_digest == previous
      attributes = entry.attributes.symbolize_keys.slice(:action, :metadata, :ip_address, :user_agent, :previous_digest, :created_at, :updated_at, :actor_id, :auditable_type, :auditable_id)
      digest_valid = ActiveSupport::SecurityUtils.secure_compare(entry.entry_digest.to_s, OpenSSL::HMAC.hexdigest("SHA256", audit_key, digest_payload(attributes)))
      previous = entry.entry_digest
      link_valid && digest_valid
    end
  end


  def self.audit_key
    Rails.application.key_generator.generate_key("audit-log-chain", 32)
  end
  def self.digest_payload(attributes)
    [
      attributes[:action], canonical_value(attributes[:metadata]), attributes[:ip_address], attributes[:user_agent],
      attributes[:previous_digest], attributes[:created_at]&.utc&.iso8601(6), attributes[:updated_at]&.utc&.iso8601(6),
      attributes[:actor_id], attributes[:auditable_type], attributes[:auditable_id]
    ].to_json
  end
  def self.canonical_value(value)
    case value
    when Hash then value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { |nested| canonical_value(nested) }
    when Array then value.map { |nested| canonical_value(nested) }
    else value
    end
  end
  private_class_method :audit_key, :digest_payload, :canonical_value
end
