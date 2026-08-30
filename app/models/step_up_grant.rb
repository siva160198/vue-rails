class StepUpGrant < ApplicationRecord
  LIFETIME = 10.minutes

  belongs_to :user
  validates :purpose, :authentication_version, :expires_at, presence: true

  def self.issue_for!(user, purpose)
    create!(user: user, purpose: purpose, authentication_version: user.authentication_version, expires_at: LIFETIME.from_now).signed_id(purpose: :step_up_grant, expires_in: LIFETIME)
  end

  def self.consume(token, user, purpose)
    grant = find_signed(token, purpose: :step_up_grant)
    return false unless grant&.user == user && grant.purpose == purpose && grant.authentication_version == user.authentication_version

    grant.with_lock do
      return false if grant.consumed_at? || grant.expires_at <= Time.current

      grant.update!(consumed_at: Time.current)
      true
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    false
  end
end
