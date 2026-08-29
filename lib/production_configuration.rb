require "uri"

class ProductionConfiguration
  REQUIRED = %w[APP_HOST FRONTEND_URL DATABASE_URL MAILER_FROM SUPPORT_EMAIL SMTP_ADDRESS].freeze
  PLACEHOLDER_PATTERN = /(example\.(com|mail)|database\.example\.com)/i
  INTEGER_RANGES = { "MAX_ACTIVE_SESSIONS" => 1..100, "QUEUE_MAX_LATENCY_SECONDS" => 30..3600, "SESSION_RETENTION_DAYS" => 1..365, "AUDIT_LOG_RETENTION_DAYS" => 30..3650, "BACKUP_RETENTION_DAYS" => 1..365 }.freeze

  def self.validate!(environment = ENV)
    missing = REQUIRED.select { |key| environment[key].to_s.strip.empty? }
    placeholders = REQUIRED.select { |key| environment[key].to_s.match?(PLACEHOLDER_PATTERN) }
    invalid = []
    invalid << "APP_HOST" unless hostname?(environment["APP_HOST"])
    invalid << "FRONTEND_URL" unless https_url?(environment["FRONTEND_URL"])
    invalid << "DATABASE_URL" unless postgres_url?(environment["DATABASE_URL"])
    invalid.concat(%w[MAILER_FROM SUPPORT_EMAIL].reject { |key| email?(environment[key]) })
    invalid << "SMTP_ADDRESS" unless hostname?(environment["SMTP_ADDRESS"])
    INTEGER_RANGES.each do |key, range|
      invalid << key unless integer_in_range?(environment.fetch(key, range.begin.to_s), range)
    end
    s3_keys = %w[S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY S3_BUCKET]
    invalid << "S3_CONFIGURATION" if s3_keys.any? { |key| environment[key].present? } && s3_keys.any? { |key| environment[key].blank? }

    problems = []
    problems << "missing: #{missing.join(', ')}" if missing.any?
    problems << "placeholder values: #{placeholders.join(', ')}" if placeholders.any?
    problems << "invalid: #{invalid.join(', ')}" if invalid.any?
    raise "Invalid production configuration (#{problems.join('; ')})" if problems.any?

    true
  end

  def self.https_url?(value)
    URI.parse(value.to_s).then { |uri| uri.is_a?(URI::HTTPS) && uri.host.present? }
  rescue URI::InvalidURIError
    false
  end

  def self.postgres_url?(value)
    URI.parse(value.to_s).then { |uri| %w[postgres postgresql].include?(uri.scheme) && uri.host.present? }
  rescue URI::InvalidURIError
    false
  end

  def self.hostname?(value)
    value.to_s.match?(/\A(?=.{1,253}\z)(?!-)(?:[a-z0-9-]+\.)*[a-z0-9-]+\z/i)
  end

  def self.email?(value)
    value.to_s.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
  end

  def self.integer_in_range?(value, range)
    range.cover?(Integer(value, 10))
  rescue ArgumentError, TypeError
    false
  end

  private_class_method :https_url?, :postgres_url?, :hostname?, :email?, :integer_in_range?
end
