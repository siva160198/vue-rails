module AdminDualControl
  extend ActiveSupport::Concern

  private
    def require_admin_dual_control!(action_key, payload)
      return true unless ENV.fetch("ADMIN_DUAL_CONTROL_ENABLED", "false") == "true"

      normalized = canonical_security_payload(payload)
      digest = Digest::SHA256.hexdigest(normalized.to_json)
      approval = AdminApproval.active.where(requester: Current.user, action_key: action_key, payload_digest: digest).order(created_at: :desc).first
      consumed = approval&.with_lock do
        approval.reload
        next false unless approval.approved?

        approval.update!(consumed_at: Time.current)
        true
      end
      if consumed
        AuditLog.record!(action: "admin.approval_consumed", actor: Current.user, metadata: { approval_id: approval.id }, request: request)
        return true
      end

      approval = nil if approval&.consumed_at?
      approval ||= AdminApproval.create!(requester: Current.user, action_key: action_key, payload_digest: digest, payload_summary: normalized, expires_at: AdminApproval::LIFETIME.from_now)
      AuditLog.record!(action: "admin.approval_requested", actor: Current.user, metadata: { approval_id: approval.id, action_key: action_key }, request: request) if approval.previously_new_record?
      render_api_error("SECOND_ADMIN_APPROVAL_REQUIRED", status: :conflict, details: { approval_id: approval.id })
      false
    end

    def canonical_security_payload(value)
      case value
      when ActionController::Parameters then canonical_security_payload(value.to_unsafe_h)
      when Hash then value.transform_keys(&:to_s).sort.to_h.transform_values { |nested| canonical_security_payload(nested) }
      when Array then value.map { |nested| canonical_security_payload(nested) }
      else value
      end
    end
end
