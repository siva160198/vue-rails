class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :login_challenges, dependent: :destroy
  has_many :email_change_challenges, dependent: :destroy
  has_many :webauthn_credentials, dependent: :destroy
  has_many :step_up_challenges, dependent: :destroy
  has_many :step_up_grants, dependent: :destroy
  has_many :password_histories, dependent: :destroy
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor
  has_one_attached :avatar
  belongs_to :role_record, class_name: "Role", foreign_key: :role, primary_key: :key, inverse_of: :users, optional: true

  scope :admin, -> { where(role: "admin") }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
  validates :active, inclusion: { in: [ true, false ] }
  validates :role, inclusion: { in: ->(_user) { Role.pluck(:key) } }
  validates :first_name, :last_name, length: { maximum: 80 }, allow_blank: true
  validates :phone, length: { maximum: 30 }, format: { with: /\A[+0-9() .-]+\z/ }, allow_blank: true
  validate :acceptable_avatar
  validate :password_not_reused, if: -> { password.present? }
  validate :password_not_compromised, if: -> { password.present? }
  after_update :remember_previous_password, if: :saved_change_to_password_digest?

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

  def login_locked?
    locked_until.present? && locked_until > Time.current
  end

  def phone
    SecurityEncryptor.decrypt(self[:phone], purpose: "phone")
  end

  def phone=(value)
    normalized = value.presence
    self[:phone] = normalized && SecurityEncryptor.encrypt(normalized, purpose: "phone")
  end

  def totp_secret
    SecurityEncryptor.decrypt(self[:totp_secret], purpose: "totp")
  end

  def totp_secret=(value)
    self[:totp_secret] = value.presence && SecurityEncryptor.encrypt(value, purpose: "totp")
  end

  def pending_totp_secret
    SecurityEncryptor.decrypt(self[:pending_totp_secret], purpose: "pending-totp")
  end

  def pending_totp_secret=(value)
    self[:pending_totp_secret] = value.presence && SecurityEncryptor.encrypt(value, purpose: "pending-totp")
  end

  def totp_enabled?
    totp_enabled_at.present? && totp_secret.present?
  end

  def verify_totp(code)
    with_lock do
      reload
      return false unless totp_enabled?

      counter = TotpAuthenticator.matching_counter(totp_secret, code)
      return false unless counter && (last_totp_counter.nil? || counter > last_totp_counter)

      update_column(:last_totp_counter, counter)
      true
    end
  end

  def mfa_enabled?
    totp_enabled? || webauthn_credentials.exists?
  end

  def regenerate_recovery_codes!
    codes = 8.times.map { SecureRandom.hex(5) }
    update!(recovery_code_digests: codes.map { |code| BCrypt::Password.create(code) })
    codes
  end

  def consume_recovery_code(code)
    with_lock do
      reload
      index = recovery_code_digests.index { |digest| BCrypt::Password.new(digest).is_password?(code.to_s) }
      return false unless index

      update!(recovery_code_digests: recovery_code_digests.without(recovery_code_digests[index]))
      true
    end
  end

  private
    def password_not_reused
      reused = password_histories.order(created_at: :desc).limit(5).any? do |history|
        BCrypt::Password.new(history.password_digest).is_password?(password)
      end
      errors.add(:password, :reused) if reused
    end

    def password_not_compromised
      errors.add(:password, :compromised) if CompromisedPasswordChecker.compromised?(password)
    end

    def remember_previous_password
      previous = password_digest_before_last_save
      return if previous.blank?

      password_histories.create!(password_digest: previous)
      password_histories.order(created_at: :desc).offset(5).delete_all
    end

    def acceptable_avatar
      return unless avatar.attached?

      errors.add(:avatar, :invalid) unless avatar.blob.content_type == "image/avif"
      errors.add(:avatar, :too_large) if avatar.blob.byte_size > AvatarProcessor::MAX_OUTPUT_BYTES
    end
end
