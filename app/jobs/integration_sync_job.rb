class IntegrationSyncJob < ApplicationJob
  queue_as :integrations
  def perform(id)
    connection = IntegrationConnection.find_by(id: id)
    return unless connection
    continuation = false
    version = nil
    connection.with_lock do
      return unless connection.status.in?(%w[queued syncing retry_wait])
      return if connection.next_sync_at && connection.next_sync_at > Time.current
      version = connection.updated_at
      adapter = DataPipelines::Registry.integrations.fetch(connection.provider_key)
      raise Pundit::NotAuthorizedError unless connection.owner.active? && adapter.authorized?(connection.owner)
      cursor = connection.cursor
      # Fetch exactly one bounded page. Adapter HTTP calls require hard timeouts.
      page = adapter.fetch_page(credentials: connection.credentials, cursor: cursor, limit: DataPipelines::Sync::PAGE_SIZE)
      items = page.fetch(:items)
      next_cursor = page[:next_cursor]
      raise ArgumentError, "Invalid page" unless items.is_a?(Array) && items.size <= DataPipelines::Sync::PAGE_SIZE
      raise ArgumentError, "Repeated cursor" if next_cursor && (next_cursor == cursor || items.empty?)
      raise ArgumentError, "Sync too large" if connection.processed_items + items.size > DataPipelines::Sync::MAX_ITEMS
      items.each do |item|
        external_id = item.fetch(:id).to_s
        payload = item.fetch(:payload).to_json
        raise ArgumentError, "Oversized item" unless external_id.bytesize.between?(1, 128) && payload.bytesize <= DataPipelines::Sync::MAX_PAYLOAD_BYTES
        connection.items.find_or_initialize_by(external_id: external_id).update!(payload_ciphertext: SecurityEncryptor.encrypt(payload, purpose: "integration-item"))
      end
      raise ArgumentError, "Oversized cursor" if next_cursor && next_cursor.to_json.bytesize > 4096
      continuation = next_cursor.present?
      connection.update!(status: continuation ? "syncing" : "idle", recovery_attempts: 0, attempts: 0, failure_code: nil, processed_items: connection.processed_items + items.size,
        cursor_ciphertext: continuation ? SecurityEncryptor.encrypt(next_cursor.to_json, purpose: "integration-cursor") : nil,
        next_sync_at: continuation ? Time.current + 1.second : nil, heartbeat_at: Time.current, last_synced_at: continuation ? connection.last_synced_at : Time.current)
    end
    self.class.set(wait: 1.second).perform_later(id) if continuation
  rescue DataPipelines::Sync::TransientFailure => error
    wait = error.retry_after
    connection.with_lock do
      return unless connection.updated_at == version
      attempts = connection.attempts + 1
      connection.update!(attempts: attempts, status: attempts < 3 ? "retry_wait" : "failed", failure_code: "INTEGRATION_TEMPORARY_FAILURE", next_sync_at: Time.current + wait.seconds)
    end
    self.class.set(wait: wait.seconds).perform_later(id) if connection.attempts < 3
  rescue DataPipelines::Sync::AuthenticationExpired
    transition_failure(connection, version, "reconnect_required", "INTEGRATION_RECONNECT_REQUIRED")
  rescue Pundit::NotAuthorizedError, KeyError
    transition_failure(connection, version, "failed", "INTEGRATION_ACCESS_REVOKED")
  rescue StandardError
    transition_failure(connection, version, "failed", "INTEGRATION_SYNC_FAILED")
    Rails.logger.error({ event: "operational_alert", code: "INTEGRATION_SYNC_FAILED" }.to_json)
  end

  private
    def transition_failure(connection, version, status, code)
      return unless connection && version
      connection.with_lock do
        connection.update!(status: status, failure_code: code) if connection.updated_at == version
      end
    end
end
