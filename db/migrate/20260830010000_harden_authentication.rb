class HardenAuthentication < ActiveRecord::Migration[8.1]
  def change
    change_table :sessions, bulk: true do |t|
      t.datetime :last_seen_at
      t.datetime :expires_at
    end
    add_index :sessions, :expires_at
    execute "UPDATE sessions SET last_seen_at = updated_at, expires_at = created_at + INTERVAL '30 days'"
    change_column_null :sessions, :last_seen_at, false
    change_column_null :sessions, :expires_at, false

    change_table :users, bulk: true do |t|
      t.integer :failed_login_attempts, null: false, default: 0
      t.datetime :locked_until
      t.integer :authentication_version, null: false, default: 0
    end

    create_table :login_attempts do |t|
      t.string :email_digest, null: false
      t.string :ip_address, null: false
      t.boolean :successful, null: false, default: false
      t.timestamps
    end
    add_index :login_attempts, :created_at
    add_index :login_attempts, %i[ip_address created_at]
    add_index :login_attempts, %i[email_digest created_at]

    create_table :step_up_challenges do |t|
      t.references :user, null: false, foreign_key: true
      t.string :purpose, null: false
      t.string :code_digest, null: false
      t.integer :attempts_count, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :step_up_challenges, :expires_at
    add_index :step_up_challenges, %i[user_id purpose]
  end
end
