require "test_helper"

class ProductionConfigurationTest < ActiveSupport::TestCase
  VALID_ENVIRONMENT = {
    "APP_HOST" => "app.acme.test",
    "FRONTEND_URL" => "https://app.acme.test",
    "DATABASE_URL" => "postgresql://user:password@db.acme.test/app_production",
    "MAILER_FROM" => "no-reply@acme.test",
    "SUPPORT_EMAIL" => "support@acme.test",
    "SMTP_ADDRESS" => "smtp.acme.test",
    "READINESS_TOKEN" => "a-secure-readiness-token-with-32-bytes"
  }.freeze

  test "accepts complete production configuration" do
    assert ProductionConfiguration.validate!(VALID_ENVIRONMENT)
  end

  test "rejects missing, placeholder, and insecure production values" do
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge(
        "APP_HOST" => "app.example.com",
        "FRONTEND_URL" => "http://app.example.com",
        "DATABASE_URL" => ""
      ))
    end

    assert_includes error.message, "missing: DATABASE_URL"
    assert_includes error.message, "placeholder values: APP_HOST, FRONTEND_URL"
    assert_includes error.message, "invalid: FRONTEND_URL, DATABASE_URL"
  end

  test "rejects unsafe operational limits and partial S3 credentials" do
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("MAX_ACTIVE_SESSIONS" => "0", "S3_BUCKET" => "uploads"))
    end

    assert_includes error.message, "MAX_ACTIVE_SESSIONS"
    assert_includes error.message, "S3_CONFIGURATION"
  end

  test "rejects an unsafe passkey count limit" do
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("MAX_PASSKEYS_PER_USER" => "1000"))
    end
    assert_includes error.message, "MAX_PASSKEYS_PER_USER"
  end

  test "rejects a short readiness token and unsafe execution timeouts" do
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge(
        "READINESS_TOKEN" => "short",
        "RACK_TIMEOUT_SERVICE_TIMEOUT" => "120",
        "DATABASE_STATEMENT_TIMEOUT_MS" => "50"
      ))
    end

    assert_includes error.message, "READINESS_TOKEN"
    assert_includes error.message, "RACK_TIMEOUT_SERVICE_TIMEOUT"
    assert_includes error.message, "DATABASE_STATEMENT_TIMEOUT_MS"
  end

  test "accepts disabled passkeys and rejects partial or insecure WebAuthn configuration" do
    assert ProductionConfiguration.validate!(VALID_ENVIRONMENT)
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("WEBAUTHN_RP_ID" => "app.acme.test", "WEBAUTHN_ORIGIN" => "http://app.acme.test"))
    end
    assert_includes error.message, "WEBAUTHN_ORIGIN"
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("WEBAUTHN_RP_ID" => "app.acme.test")) }
  end

  test "rejects unsafe session lifetimes and invalid administrator MFA flag" do
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge(
        "SESSION_IDLE_TIMEOUT_MINUTES" => "1",
        "SESSION_ABSOLUTE_LIFETIME_DAYS" => "365",
        "ADMIN_MFA_REQUIRED" => "sometimes"
      ))
    end

    assert_includes error.message, "SESSION_IDLE_TIMEOUT_MINUTES"
    assert_includes error.message, "SESSION_ABSOLUTE_LIFETIME_DAYS"
    assert_includes error.message, "ADMIN_MFA_REQUIRED"
  end

  test "rejects partial CAPTCHA configuration and invalid trusted network CIDRs" do
    error = assert_raises(RuntimeError) do
      ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge(
        "TURNSTILE_SITE_KEY" => "site-key",
        "TRUSTED_LOGIN_NETWORKS" => "10.0.0.0/8,invalid"
      ))
    end

    assert_includes error.message, "TURNSTILE_CONFIGURATION"
    assert_includes error.message, "TRUSTED_LOGIN_NETWORKS"
    assert ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge(
      "TURNSTILE_SITE_KEY" => "site-key",
      "TURNSTILE_SECRET_KEY" => "secret-key",
      "TRUSTED_LOGIN_NETWORKS" => "10.0.0.0/8,2001:db8::/32"
    ))
  end


  test "accepts only an HTTPS origin without path or credentials for cross-origin frontend access" do
    assert ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("FRONTEND_ORIGIN" => "https://frontend.acme.test"))
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("FRONTEND_ORIGIN" => "http://frontend.acme.test")) }
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("FRONTEND_ORIGIN" => "https://frontend.acme.test/app")) }
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(VALID_ENVIRONMENT.merge("FRONTEND_ORIGIN" => "https://user:pass@frontend.acme.test")) }
  end
end
