class AddEmailVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime
    execute "UPDATE users SET email_verified_at = CURRENT_TIMESTAMP"
  end

  def down
    remove_column :users, :email_verified_at
  end
end
