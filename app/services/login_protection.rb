class LoginProtection
  WINDOW = 15.minutes
  ALERT_COOLDOWN = 1.hour
  CAPTCHA_ACCOUNT_THRESHOLD = 3
  HARD_LOCK_THRESHOLD = 8
  HARD_LOCK_RISK = 55
  CAPTCHA_RISK = 35
  IP_FAILURE_LIMIT = 20
  IP_DISTINCT_ACCOUNT_LIMIT = 5
  LOCK_DURATION = 15.minutes
  MAX_DELAY = 2.seconds

  def initialize(email_address:, ip_address:, user_agent: nil, captcha_enabled: CaptchaVerifier.enabled?)
    @email_digest = Digest::SHA256.hexdigest(email_address.to_s.strip.downcase)
    @ip_address = ip_address.to_s
    @user_agent = user_agent.to_s
    @device_digest = Digest::SHA256.hexdigest(@user_agent)
    @captcha_enabled = captcha_enabled
  end

  attr_reader :email_digest, :ip_address, :device_digest

  def trusted_network?
    TrustedLoginNetworks.include?(ip_address)
  end

  def risk_score(user = nil)
    return 0 if trusted_network?

    recent = recent_ip_failures
    score = [ recent.count * 2, 30 ].min
    score += 25 if recent.distinct.count(:email_digest) >= IP_DISTINCT_ACCOUNT_LIMIT
    account_pressure = [ recent_account_failures, user&.failed_login_attempts.to_i ].max
    score += [ account_pressure * 6, 30 ].min
    score += 15 if user.nil? || !user.sessions.where(user_agent: @user_agent).exists?
    score.clamp(0, 100)
  end

  def captcha_required?(user = nil)
    @captcha_enabled && !trusted_network? && (
      user&.login_locked? || user&.failed_login_attempts.to_i >= CAPTCHA_ACCOUNT_THRESHOLD || risk_score(user) >= CAPTCHA_RISK
    )
  end

  def ip_attack?
    recent = recent_ip_failures
    recent.count >= IP_FAILURE_LIMIT && recent.distinct.count(:email_digest) >= IP_DISTINCT_ACCOUNT_LIMIT
  end

  def hard_locked?(user, captcha_verified: false)
    locked_signal = user&.login_locked? || recent_account_failures >= HARD_LOCK_THRESHOLD
    !trusted_network? && !captcha_verified && locked_signal && risk_score(user) >= HARD_LOCK_RISK
  end

  def delay!
    return if trusted_network?

    sleep(delay_seconds) if delay_seconds.positive? && !Rails.env.test?
  end

  def delay_seconds
    [ 0.15 * (2**[ recent_account_failures, 4 ].min), MAX_DELAY ].min
  end

  def record_failure!(user = nil, captcha_verified: false)
    score = risk_score(user)
    LoginAttempt.create!(email_digest: email_digest, ip_address: ip_address, device_digest: device_digest, risk_score: score, captcha_verified: captcha_verified, successful: false)
    return { locked: false, risk_score: score } unless user

    attempts = user.failed_login_attempts + 1
    should_lock = attempts >= HARD_LOCK_THRESHOLD && score >= HARD_LOCK_RISK && !trusted_network?
    user.update_columns(failed_login_attempts: attempts, locked_until: should_lock ? LOCK_DURATION.from_now : nil, updated_at: Time.current)
    { locked: should_lock, risk_score: score }
  end

  def record_success!(user)
    LoginAttempt.create!(email_digest: email_digest, ip_address: ip_address, device_digest: device_digest, risk_score: risk_score(user), successful: true)
    user.update_columns(failed_login_attempts: 0, locked_until: nil, updated_at: Time.current) if user.failed_login_attempts.positive? || user.locked_until?
  end

  def alert_due?(user)
    user && (user.security_alerted_at.nil? || user.security_alerted_at <= ALERT_COOLDOWN.ago)
  end

  private
    def recent_ip_failures
      LoginAttempt.where(ip_address: ip_address, successful: false, created_at: WINDOW.ago..)
    end

    def recent_account_failures
      LoginAttempt.where(email_digest: email_digest, successful: false, created_at: WINDOW.ago..).count
    end
end
