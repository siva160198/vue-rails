class Session < ApplicationRecord
  belongs_to :user
  before_validation :set_security_timestamps, on: :create

  scope :active, -> { where("expires_at > ? AND last_seen_at > ?", Time.current, Session.idle_timeout.ago) }

  def self.idle_timeout
    Integer(ENV.fetch("SESSION_IDLE_TIMEOUT_MINUTES", "30"), 10).clamp(5, 1_440).minutes
  end

  def self.absolute_lifetime
    Integer(ENV.fetch("SESSION_ABSOLUTE_LIFETIME_DAYS", "30"), 10).clamp(1, 90).days
  end

  def self.absolute_lifetime_for(user)
    return absolute_lifetime unless user&.admin?

    Integer(ENV.fetch("ADMIN_SESSION_ABSOLUTE_HOURS", "12"), 10).clamp(1, 168).hours
  end

  def expired?
    expires_at.blank? || expires_at <= Time.current || last_seen_at.blank? || last_seen_at <= self.class.idle_timeout.ago
  end

  def touch_activity!
    return if last_seen_at && last_seen_at > 1.minute.ago

    update_column(:last_seen_at, Time.current)
  end


  private
    def set_security_timestamps
      self.last_seen_at ||= Time.current
      self.expires_at ||= self.class.absolute_lifetime_for(user).from_now
    end
end
