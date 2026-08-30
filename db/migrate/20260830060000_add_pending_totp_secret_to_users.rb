class AddPendingTotpSecretToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pending_totp_secret, :string
  end
end
