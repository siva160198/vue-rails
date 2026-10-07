require "digest"
require "securerandom"
require "time"

class OffsiteBackup
  def initialize(environment: ENV, resource: nil)
    @environment, @resource = environment, resource
  end

  def upload(path)
    raise ArgumentError, "Unsafe backup file" unless File.file?(path) && !File.symlink?(path) && File.basename(path).match?(/\Avue_rails-[a-zA-Z0-9_-]+\.dump\z/) && (File.stat(path).mode & 0o077).zero?
    bucket = @environment.fetch("OFFSITE_BACKUP_BUCKET")
    kms = @environment.fetch("OFFSITE_BACKUP_KMS_KEY_ID")
    raise ArgumentError, "Missing offsite configuration" if bucket.empty? || kms.empty?
    digest = Digest::SHA256.file(path).hexdigest
    key = "backups/#{Time.now.utc.strftime('%Y/%m/%d')}/#{SecureRandom.uuid}.dump"
    require "aws-sdk-s3" unless @resource
    resource = @resource || Aws::S3::Resource.new(region: @environment.fetch("OFFSITE_BACKUP_REGION", "us-east-1"), retry_limit: 2, http_open_timeout: 3, http_read_timeout: 30)
    object = resource.bucket(bucket).object(key)
    object.upload_file(path, server_side_encryption: "aws:kms", ssekms_key_id: kms, metadata: { "sha256" => digest }, content_type: "application/octet-stream")
    head = object.client.head_object(bucket: bucket, key: key)
    raise "Offsite verification failed" unless head.content_length == File.size(path) && head.metadata["sha256"] == digest && head.server_side_encryption == "aws:kms"
    { sha256: digest, completed_at: Time.now.utc.iso8601 }
  end
end
