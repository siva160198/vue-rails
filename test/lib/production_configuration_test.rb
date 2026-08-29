require "test_helper"

class ProductionConfigurationTest < ActiveSupport::TestCase
  VALID_ENVIRONMENT = {
    "APP_HOST" => "app.acme.test",
    "FRONTEND_URL" => "https://app.acme.test",
    "DATABASE_URL" => "postgresql://user:password@db.acme.test/app_production",
    "MAILER_FROM" => "no-reply@acme.test",
    "SUPPORT_EMAIL" => "support@acme.test",
    "SMTP_ADDRESS" => "smtp.acme.test"
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
end
