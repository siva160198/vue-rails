class ImportRun < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :rows, class_name: "ImportRow", dependent: :delete_all
  validates :status, inclusion: { in: %w[queued staging processing completed failed] }
  validates :adapter_key, :source_digest, :submission_key, presence: true
  validates :submission_key, format: { with: /\A[a-zA-Z0-9_-]{16,80}\z/ }

  def self.submit!(owner:, adapter_key:, io:, submission_key:)
    adapter = DataPipelines::Registry.imports.fetch(adapter_key)
    raise Pundit::NotAuthorizedError unless owner.active? && adapter.authorized?(owner)
    source = DataPipelines::CsvDocument.read(io)
    digest = Digest::SHA256.hexdigest(source)
    created = false
    run = owner.with_lock do
      existing = where(owner: owner, adapter_key: adapter_key, submission_key: submission_key).first
      if existing
        existing
      else
        raise ArgumentError, "Too many pending imports" if where(owner: owner, status: %w[queued staging processing]).limit(3).count >= 3
        created = true
        create!(owner: owner, adapter_key: adapter_key, submission_key: submission_key, source_digest: digest,
          source_ciphertext: SecurityEncryptor.encrypt(source.to_json, purpose: "import-source"))
      end
    end
    raise ArgumentError, "Submission key reused for another file" unless run.source_digest == digest
    ImportPipelineJob.perform_later(run.id) if created
    run
  end

  def progress
    { id: id, status: status, total_rows: total_rows, processed_rows: processed_rows, failed_rows: failed_rows, failure_code: failure_code, finished_at: finished_at }
  end

  def failures_csv
    DataPipelines::CsvDocument.export(%w[row code], rows.where(status: "failed").order(:position).pluck(:position, :failure_code))
  end

  def self.sample_csv(owner:, adapter_key:)
    adapter = DataPipelines::Registry.imports.fetch(adapter_key)
    raise Pundit::NotAuthorizedError unless owner.active? && adapter.authorized?(owner)
    DataPipelines::CsvDocument.export(adapter.headers, adapter.sample_rows.first(5))
  end
end
