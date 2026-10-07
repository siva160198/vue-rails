class AddTrustedDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :trusted_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :binding_digest, null: false
      t.string :fingerprint, null: false
      t.string :access_digest, null: false
      t.integer :authentication_version, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at, null: false
      t.timestamps
    end
    add_index :trusted_devices, :token_digest, unique: true
    add_index :trusted_devices, :expires_at
    add_reference :sessions, :trusted_device, foreign_key: { on_delete: :nullify }
  end
end
