class TrustedDevice < ApplicationRecord
  LIFETIME = 30.days
  MAX_PER_USER = 10
  belongs_to :user
  has_many :sessions, dependent: :destroy

  def self.digest(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def self.access_digest(user)
    digest([ user.role, user.active?, user.login_otp_required?, user.password_digest, user.email_address, user.totp_enabled_at, user[:totp_secret], user.recovery_code_digests.join(","), user.permission_keys.join(","), user.webauthn_credentials.order(:id).pluck(:id).join(",") ].join(":"))
  end

  def self.issue!(user, user_agent:)
    token = SecureRandom.urlsafe_base64(32)
    binding = SecureRandom.urlsafe_base64(32)
    device = nil
    user.with_lock do
      user.trusted_devices.order(created_at: :desc).offset(MAX_PER_USER - 1).destroy_all
      device = user.trusted_devices.create!(token_digest: digest(token), binding_digest: digest(binding),
        fingerprint: digest(user_agent), access_digest: access_digest(user),
        authentication_version: user.authentication_version, expires_at: LIFETIME.from_now, last_used_at: Time.current)
    end
    [ device, token, binding ]
  end

  def valid_binding?(user:, binding:, user_agent:)
    user.active? && user.email_verified? && !user.role_requires_login_otp? &&
      expires_at > Time.current && authentication_version == user.authentication_version &&
      access_digest == self.class.access_digest(user) &&
      ActiveSupport::SecurityUtils.secure_compare(binding_digest, self.class.digest(binding)) &&
      fingerprint == self.class.digest(user_agent)
  end

  def self.consume!(user, token:, binding:, user_agent:)
    return if token.blank? || binding.blank? || user.role_requires_login_otp?

    user.with_lock do
      device = user.trusted_devices.find_by(token_digest: digest(token))
      unless device&.valid_binding?(user: user, binding: binding, user_agent: user_agent)
        device&.update!(expires_at: Time.current)
        return
      end

      rotated = SecureRandom.urlsafe_base64(32)
      device.update!(token_digest: digest(rotated), last_used_at: Time.current)
      [ device, rotated ]
    end
  end
end
