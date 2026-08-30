class AdminApproval < ApplicationRecord
  LIFETIME = 30.minutes

  belongs_to :requester, class_name: "User"
  belongs_to :approver, class_name: "User", optional: true
  validates :action_key, :payload_digest, :expires_at, presence: true
  validate :different_approver

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :pending, -> { active.where(approved_at: nil, consumed_at: nil) }

  def approved?
    approved_at.present? && consumed_at.nil? && expires_at.future?
  end

  private
    def different_approver
      errors.add(:approver, :invalid) if approver_id.present? && approver_id == requester_id
    end
end
