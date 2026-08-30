class AddAccountSecurity < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "account_security.view" => [ "Lihat keamanan akun", "Melihat riwayat dan konfigurasi keamanan akun sendiri." ],
    "account_security.update" => [ "Ubah keamanan akun", "Mengubah password, email, recovery code, dan passkey akun sendiri." ]
  }.freeze

  def up
    add_column :users, :webauthn_user_handle, :string
    add_index :users, :webauthn_user_handle, unique: true

    create_table :email_change_challenges do |t|
      t.references :user, null: false, foreign_key: true
      t.string :email_address, null: false
      t.string :code_digest, null: false
      t.integer :attempts_count, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :email_change_challenges, :expires_at

    create_table :webauthn_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :nickname, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :webauthn_credentials, :external_id, unique: true

    PERMISSIONS.each do |key, (name, description)|
      Permission.find_or_create_by!(key: key) { |permission| permission.assign_attributes(name: name, description: description) }
    end
    Permission.where(key: PERMISSIONS.keys).find_each do |permission|
      Role.find_each { |role| role.permissions << permission unless role.permission_ids.include?(permission.id) }
    end
  end

  def down
    Permission.where(key: PERMISSIONS.keys).destroy_all
    drop_table :webauthn_credentials
    drop_table :email_change_challenges
    remove_column :users, :webauthn_user_handle
  end
end
