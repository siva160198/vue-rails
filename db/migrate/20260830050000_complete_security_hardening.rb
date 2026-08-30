class CompleteSecurityHardening < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :totp_secret, :string
    add_column :users, :totp_enabled_at, :datetime
    add_column :users, :pending_email_revert_digest, :string
    add_column :users, :pending_email_revert_address, :string
    add_column :users, :pending_email_revert_expires_at, :datetime

    create_table :password_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :password_histories, %i[user_id created_at]

    add_column :audit_logs, :previous_digest, :string
    add_column :audit_logs, :entry_digest, :string
    add_index :audit_logs, :entry_digest, unique: true
  end
end
