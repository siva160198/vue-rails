class IntegrationConnection < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :items, class_name: "IntegrationItem", dependent: :delete_all
  validates :provider_key, presence: true
  validates :status, inclusion: { in: %w[idle queued syncing retry_wait reconnect_required failed] }

  def credentials=(value)
    self.credentials_ciphertext = SecurityEncryptor.encrypt(value.to_json, purpose: "integration-credentials")
  end

  def credentials
    plaintext = SecurityEncryptor.decrypt(credentials_ciphertext, purpose: "integration-credentials")
    raise DataPipelines::Sync::AuthenticationExpired unless plaintext
    JSON.parse(plaintext)
  end

  def cursor
    plaintext = SecurityEncryptor.decrypt(cursor_ciphertext, purpose: "integration-cursor")
    JSON.parse(plaintext) if plaintext
  end

  def request_sync!
    adapter = DataPipelines::Registry.integrations.fetch(provider_key)
    raise Pundit::NotAuthorizedError unless owner.active? && adapter.authorized?(owner)
    with_lock do
      return false if status.in?(%w[queued syncing retry_wait])
      update!(status: "queued", recovery_attempts: 0, attempts: 0, failure_code: nil, processed_items: 0, cursor_ciphertext: nil, next_sync_at: Time.current)
    end
    IntegrationSyncJob.perform_later(id)
    true
  end
end
