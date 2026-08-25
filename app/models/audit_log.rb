class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  def self.record!(action:, actor: nil, auditable: nil, metadata: {}, request: nil)
    create!(
      action: action,
      actor: actor,
      auditable: auditable,
      metadata: metadata,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end
end
