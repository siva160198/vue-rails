require "test_helper"
require "tempfile"

class OperationsTest < ActiveSupport::TestCase
  test "deployment evidence rejects blanks stale tests and missing acceptance" do
    assert DeploymentEvidence.problems({}).include?("security_owner")
    doc = DeploymentEvidence::REQUIRED.to_h { |key| [ key, "owner" ] }.merge(
      "risks_accepted" => true, "audit_sink_tested_on" => Date.today.to_s,
      "alert_delivery_tested_on" => Date.today.to_s, "offsite_backup_verified_on" => Date.today.to_s,
      "restore_drill_on" => Date.today.to_s, "next_review_on" => (Date.today + 30).to_s,
      "rpo_minutes" => 1440, "rto_minutes" => 60)
    assert_empty DeploymentEvidence.problems(doc)
    assert_includes DeploymentEvidence.problems(doc.merge("restore_drill_on" => (Date.today - 40).to_s)), "restore_drill_on"
    assert_includes DeploymentEvidence.problems(doc.merge("next_review_on" => "invalid", "risks_accepted" => false)), "risks_accepted"
    assert_includes DeploymentEvidence.problems(doc.merge("rpo_minutes" => 0)), "rpo_minutes"
  end
  test "PostgreSQL commands never put a password in argv" do
    calls = []
    original = PostgresCommand.method(:system)
    PostgresCommand.define_singleton_method(:system) { |*args| calls << args; true }
    assert PostgresCommand.run("pg_dump", [ "--format=custom" ], database_url: "postgresql://user:private%2Btoken@localhost/database?sslmode=require")
    assert_equal "private+token", calls.last.first["PGPASSWORD"]
    assert_equal "postgresql://user@localhost/database?sslmode=require", calls.last.last
    assert PostgresCommand.run("pg_restore", [ "--dbname" ], database_url: "postgresql://user@localhost/database?password=secret+literal&sslmode=require")
    assert_equal "secret+literal", calls.last.first["PGPASSWORD"]
    refute_includes calls.last.last, "password"
    assert_raises(ArgumentError) { PostgresCommand.run("pg_dump", [], database_url: "https://invalid.test") }
  ensure
    PostgresCommand.define_singleton_method(:system, original) if original
  end
  test "offsite uploader enforces private file encryption and checksum metadata" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "vue_rails-test.dump")
      File.write(path, "private database", perm: 0o600)
      options = nil
      object = Object.new
      object.define_singleton_method(:upload_file) { |file, **opts| options = opts }
      object.define_singleton_method(:client) { self }
      object.define_singleton_method(:head_object) do |**|
        Struct.new(:content_length, :metadata, :server_side_encryption).new(File.size(path), { "sha256" => Digest::SHA256.file(path).hexdigest }, "aws:kms")
      end
      bucket = Object.new
      bucket.define_singleton_method(:object) { |key| object }
      resource = Object.new
      resource.define_singleton_method(:bucket) { |name| bucket }
      uploader = OffsiteBackup.new(environment: { "OFFSITE_BACKUP_BUCKET" => "private-backups", "OFFSITE_BACKUP_KMS_KEY_ID" => "kms-key" }, resource: resource)
      result = uploader.upload(path)
      assert_equal "aws:kms", options[:server_side_encryption]
      assert_equal "kms-key", options[:ssekms_key_id]
      assert_equal Digest::SHA256.file(path).hexdigest, result[:sha256]
      File.chmod(0o644, path)
      assert_raises(ArgumentError) { uploader.upload(path) }
      File.chmod(0o600, path)
      object.define_singleton_method(:head_object) do |**|
        Struct.new(:content_length, :metadata, :server_side_encryption).new(0, {}, "AES256")
      end
      assert_raises(RuntimeError) { uploader.upload(path) }
      assert_raises(ArgumentError) { OffsiteBackup.new(environment: { "OFFSITE_BACKUP_BUCKET" => "", "OFFSITE_BACKUP_KMS_KEY_ID" => "" }, resource: resource).upload(path) }
    end
  end
  test "optional monitors remain inactive and backup absence is unhealthy" do
    old = ENV["OPERATIONS_MONITOR_ENABLED"]
    old_backup = ENV["BACKUP_STATUS_FILE"]
    ENV["OPERATIONS_MONITOR_ENABLED"] = "false"
    ENV.delete("BACKUP_STATUS_FILE")
    assert_nil OperationsMonitorJob.perform_now
    result = Operations::HealthCheck.new.call
    refute result[:healthy]
    refute result[:checks][:backup_age]
  ensure
    ENV["OPERATIONS_MONITOR_ENABLED"] = old
    ENV["BACKUP_STATUS_FILE"] = old_backup
  end
  test "operational limits and enabled monitors require explicit production configuration" do
    environment = ProductionConfigurationTest::VALID_ENVIRONMENT rescue {
      "APP_HOST" => "app.acme.test", "FRONTEND_URL" => "https://app.acme.test", "DATABASE_URL" => "postgresql://db.acme.test/app", "MAILER_FROM" => "no-reply@acme.test", "SUPPORT_EMAIL" => "support@acme.test", "SMTP_ADDRESS" => "smtp.acme.test", "READINESS_TOKEN" => "a" * 32 }
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(environment.merge("PIPELINE_RETENTION_DAYS" => "0")) }
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(environment.merge("OPERATIONS_MONITOR_ENABLED" => "true")) }
    assert_raises(RuntimeError) { ProductionConfiguration.validate!(environment.merge("OFFSITE_BACKUP_BUCKET" => "private")) }
  end
end
