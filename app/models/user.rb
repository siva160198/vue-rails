class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :login_challenges, dependent: :destroy
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor
  has_one_attached :avatar
  belongs_to :role_record, class_name: "Role", foreign_key: :role, primary_key: :key, inverse_of: :users

  scope :admin, -> { where(role: "admin") }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
  validates :active, inclusion: { in: [ true, false ] }
  validate :acceptable_avatar

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

  def regenerate_recovery_codes!
    codes = 8.times.map { SecureRandom.hex(5) }
    update!(recovery_code_digests: codes.map { |code| BCrypt::Password.create(code) })
    codes
  end

  def consume_recovery_code(code)
    index = recovery_code_digests.index { |digest| BCrypt::Password.new(digest).is_password?(code.to_s) }
    return false unless index

    update!(recovery_code_digests: recovery_code_digests.without(recovery_code_digests[index]))
    true
  end

  private
    def acceptable_avatar
      return unless avatar.attached?

      errors.add(:avatar, :invalid) unless avatar.blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:avatar, :too_large) if avatar.blob.byte_size > 5.megabytes
    end
end
