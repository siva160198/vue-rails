class IntegrationItem < ApplicationRecord
  belongs_to :integration_connection
  validates :external_id, length: { in: 1..128 }
  def payload
    JSON.parse(SecurityEncryptor.decrypt(payload_ciphertext, purpose: "integration-item"))
  end
end
