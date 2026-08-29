Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production staging]
  config.environment = ENV.fetch("APP_ENV", Rails.env)
  config.release = ENV["APP_RELEASE"] if ENV["APP_RELEASE"].present?
  config.send_default_pii = false
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0").to_f.clamp(0, 1)
end
