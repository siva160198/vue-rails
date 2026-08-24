class PasswordResetChallenge < ApplicationRecord
  CODE_LENGTH = 6
  LIFETIME = 10.minutes
  MAX_ATTEMPTS = 5

  belongs_to :user
  has_secure_password :code, validations: false

  validates :code_digest, :expires_at, presence: true

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def self.issue_for!(user)
    transaction do
      user.password_reset_challenges.active.update_all(consumed_at: Time.current)
      code = format("%0#{CODE_LENGTH}d", SecureRandom.random_number(10**CODE_LENGTH))
      challenge = user.password_reset_challenges.create!(code: code, expires_at: LIFETIME.from_now)
      [ challenge, code ]
    end
  end

  def reset_password(code:, password:, password_confirmation:)
    with_lock do
      return [ :expired, nil ] if consumed_at? || expires_at <= Time.current
      return [ :locked, nil ] if attempts_count >= MAX_ATTEMPTS

      increment!(:attempts_count)
      unless authenticate_code(code.to_s)
        update!(consumed_at: Time.current) if attempts_count >= MAX_ATTEMPTS
        return [ attempts_count >= MAX_ATTEMPTS ? :locked : :invalid, nil ]
      end

      user.assign_attributes(password: password, password_confirmation: password_confirmation)
      return [ :invalid_password, user.errors ] unless user.valid?

      transaction do
        user.save!
        user.sessions.destroy_all
        update!(consumed_at: Time.current)
      end

      [ :reset, nil ]
    end
  end

  def token
    signed_id(purpose: :password_reset_otp, expires_in: LIFETIME)
  end
end
