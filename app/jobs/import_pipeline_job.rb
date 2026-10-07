class ImportPipelineJob < ApplicationJob
  queue_as :imports
  BATCH_SIZE = 50

  def perform(id)
    run = ImportRun.find_by(id: id)
    return unless run
    continue = false
    run.with_lock do
      return if run.status.in?(%w[completed failed])
      adapter = DataPipelines::Registry.imports.fetch(run.adapter_key)
      raise Pundit::NotAuthorizedError unless run.owner.active? && adapter.authorized?(run.owner)
      stage(run, adapter) if run.status.in?(%w[queued staging])
      run.rows.where(status: "pending").order(:position).limit(BATCH_SIZE).each do |row|
        # Domain writes and row outcome commit together in the primary database.
        # Remote side effects MUST independently honor the stable idempotency key.
        begin
          ApplicationRecord.transaction(requires_new: true) do
            adapter.process!(row.payload, owner: run.owner, idempotency_key: "import:#{run.id}:#{row.position}")
            row.update!(status: "succeeded", payload_ciphertext: nil)
          end
        rescue ActiveRecord::RecordInvalid, DataPipelines::CsvDocument::Invalid
          row.update!(status: "failed", failure_code: "CSV_ROW_INVALID", payload_ciphertext: nil)
          run.failed_rows += 1
        end
        run.processed_rows += 1
      end
      continue = run.rows.where(status: "pending").exists?
      run.update!(status: continue ? "processing" : "completed", recovery_attempts: 0, heartbeat_at: Time.current, finished_at: continue ? nil : Time.current)
    end
    self.class.perform_later(id) if continue
  rescue DataPipelines::CsvDocument::Invalid => error
    fail_run(run, error.code)
  rescue Pundit::NotAuthorizedError, KeyError
    fail_run(run, "CSV_ACCESS_REVOKED")
  rescue StandardError
    # Persist only a stable code, never adapter errors that may contain row PII/secrets.
    fail_run(run, "CSV_PROCESSING_FAILED")
    Rails.logger.error({ event: "operational_alert", code: "CSV_PROCESSING_FAILED" }.to_json)
  end

  private
    def stage(run, adapter)
      source = SecurityEncryptor.decrypt(run.source_ciphertext, purpose: "import-source")
      raise DataPipelines::CsvDocument::Invalid, "CSV_INVALID_PAYLOAD" unless source
      values = DataPipelines::CsvDocument.rows(JSON.parse(source), headers: adapter.headers)
      values.each_with_index do |payload, index|
        run.rows.create!(position: index + 1, payload_ciphertext: SecurityEncryptor.encrypt(payload.to_json, purpose: "import-row"))
      end
      run.update!(status: "processing", source_ciphertext: nil, total_rows: values.size)
    end

    def fail_run(run, code)
      return unless run
      run.with_lock do
        return if run.status.in?(%w[completed failed])
        run.rows.where.not(payload_ciphertext: nil).in_batches(of: BATCH_SIZE).update_all(payload_ciphertext: nil)
        run.update!(status: "failed", failure_code: code, source_ciphertext: nil, finished_at: Time.current)
      end
    end
end
