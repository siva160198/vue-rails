class AddPasskeyDeviceMetadata < ActiveRecord::Migration[8.1]
  def change
    add_column :webauthn_credentials, :transports, :jsonb, null: false, default: []
    add_column :webauthn_credentials, :authenticator_attachment, :string
  end
end
