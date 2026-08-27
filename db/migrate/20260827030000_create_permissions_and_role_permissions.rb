class CreatePermissionsAndRolePermissions < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "dashboard.view" => [ "Dashboard", "Melihat dashboard admin." ],
    "users.view" => [ "Lihat users", "Melihat daftar dan detail user." ],
    "users.update" => [ "Ubah users", "Mengubah role dan status user." ],
    "roles.view" => [ "Lihat roles", "Melihat daftar role dan permission." ],
    "roles.manage" => [ "Kelola roles", "Membuat, mengubah, dan menghapus role serta permission." ],
    "audit_logs.view" => [ "Lihat audit logs", "Melihat riwayat aktivitas keamanan." ]
  }.freeze

  def up
    create_table :permissions do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
    add_index :permissions, :key, unique: true

    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :role_permissions, %i[role_id permission_id], unique: true

    now = Time.current.to_fs(:db)
    PERMISSIONS.each do |key, (name, description)|
      execute <<~SQL.squish
        INSERT INTO permissions (key, name, description, created_at, updated_at)
        VALUES (#{connection.quote(key)}, #{connection.quote(name)}, #{connection.quote(description)}, #{connection.quote(now)}, #{connection.quote(now)})
      SQL
    end

    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, #{connection.quote(now)}, #{connection.quote(now)}
      FROM roles CROSS JOIN permissions WHERE roles.key = 'admin'
    SQL
  end

  def down
    drop_table :role_permissions
    drop_table :permissions
  end
end
