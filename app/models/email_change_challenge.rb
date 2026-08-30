class EmailChangeChallenge < ApplicationRecord
  LIFETIME = 10.minutes
  MAX_ATTEMPTS = 5

  belongs_to :user
  has_secure_password :code, validations: false
  normalizes :email_address, with: ->(email) { email.strip.downcase }
  validates :email_address, :code_digest, :expires_at, presence: true

  def self.issue_for!(user, email_address)
    transaction do
      user.email_change_challenges.where(consumed_at: nil).update_all(consumed_at: Time.current)
      code = format("%06d", SecureRandom.random_number(1_000_000))
      challenge = user.email_change_challenges.create!(email_address: email_address, code: code, expires_at: LIFETIME.from_now)
      [ challenge, code ]
    end
  end

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

  def token
    signed_id(purpose: :email_change, expires_in: LIFETIME)
  end
end
