class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :login_challenges, dependent: :destroy
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor
  belongs_to :role_record, class_name: "Role", foreign_key: :role, primary_key: :key, inverse_of: :users

  scope :admin, -> { where(role: "admin") }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
  validates :active, inclusion: { in: [ true, false ] }

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def can?(permission_key)
    role_record.permissions.exists?(key: permission_key)
  end

  def permission_keys
    role_record.permissions.order(:key).pluck(:key)
  end

  def email_verified?
    email_verified_at.present?
  end
end
