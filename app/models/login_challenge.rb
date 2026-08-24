class LoginChallenge < ApplicationRecord
  CODE_LENGTH = 6
  LIFETIME = 5.minutes
  RESEND_DELAY = 60.seconds
  MAX_ATTEMPTS = 5

  belongs_to :user
  has_secure_password :code, validations: false

  validates :code_digest, :expires_at, presence: true

  def self.issue_for!(user)
    transaction do
      user.login_challenges.active.update_all(consumed_at: Time.current)
      code = format("%0#{CODE_LENGTH}d", SecureRandom.random_number(10**CODE_LENGTH))
      challenge = user.login_challenges.create!(code: code, expires_at: LIFETIME.from_now)
      [ challenge, code ]
    end
  end

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def verify(code)
    with_lock do
      return :expired if consumed_at? || expires_at <= Time.current
      return :locked if attempts_count >= MAX_ATTEMPTS

      increment!(:attempts_count)
      if authenticate_code(code.to_s)
        update!(consumed_at: Time.current)
        :verified
      elsif attempts_count >= MAX_ATTEMPTS
        update!(consumed_at: Time.current)
        :locked
      else
        :invalid
      end
    end
  end

  def resend_available?
    usable? && created_at <= RESEND_DELAY.ago
  end

  def usable?
    consumed_at.nil? && expires_at > Time.current && attempts_count < MAX_ATTEMPTS
  end

  def token
    signed_id(purpose: :login_otp, expires_in: LIFETIME)
  end
end
