class AddTotpReplayProtectionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_totp_counter, :bigint
  end
end
