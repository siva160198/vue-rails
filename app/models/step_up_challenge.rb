class StepUpChallenge < ApplicationRecord
  LIFETIME = 5.minutes
  GRANT_LIFETIME = 10.minutes
  MAX_ATTEMPTS = 5

  belongs_to :user
  has_secure_password :code, validations: false
  validates :purpose, :code_digest, :expires_at, presence: true

  def self.issue_for!(user, purpose)
    transaction do
      user.step_up_challenges.where(purpose: purpose, consumed_at: nil).update_all(consumed_at: Time.current)
      code = format("%06d", SecureRandom.random_number(1_000_000))
      challenge = user.step_up_challenges.create!(purpose: purpose, code: code, expires_at: LIFETIME.from_now)
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
    signed_id(purpose: :step_up_challenge, expires_in: LIFETIME)
  end

  def grant_token
    StepUpGrant.issue_for!(user, purpose)
  end
end
