class ImportRow < ApplicationRecord
  belongs_to :import_run
  validates :status, inclusion: { in: %w[pending succeeded failed] }

  def payload
    plaintext = SecurityEncryptor.decrypt(payload_ciphertext, purpose: "import-row")
    raise DataPipelines::CsvDocument::Invalid, "CSV_INVALID_PAYLOAD" unless plaintext
    JSON.parse(plaintext)
  end
end
