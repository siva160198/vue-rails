class SplitRoleManagementPermissions < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "roles.create" => [ "Buat role", "Membuat role baru dan menetapkan permission awal." ],
    "roles.update" => [ "Ubah role", "Mengubah nama, deskripsi, dan permission role." ],
    "roles.delete" => [ "Hapus role", "Menghapus role kustom yang tidak digunakan." ]
  }.freeze

  def up
    now = Time.current
    PERMISSIONS.each do |key, (name, description)|
      execute <<~SQL.squish
        INSERT INTO permissions (key, name, description, created_at, updated_at)
        VALUES (#{connection.quote(key)}, #{connection.quote(name)}, #{connection.quote(description)}, #{connection.quote(now)}, #{connection.quote(now)})
        ON CONFLICT (key) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = EXCLUDED.updated_at
      SQL
    end

    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT existing.role_id, granular.id, #{connection.quote(now)}, #{connection.quote(now)}
      FROM role_permissions existing
      INNER JOIN permissions legacy ON legacy.id = existing.permission_id AND legacy.key = 'roles.manage'
      CROSS JOIN permissions granular
      WHERE granular.key IN ('roles.create', 'roles.update', 'roles.delete')
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL

    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, #{connection.quote(now)}, #{connection.quote(now)}
      FROM roles CROSS JOIN permissions
      WHERE roles.key = 'admin'
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL

    execute <<~SQL.squish
      DELETE FROM role_permissions
      WHERE permission_id IN (SELECT id FROM permissions WHERE key = 'roles.manage')
    SQL
    execute "DELETE FROM permissions WHERE key = 'roles.manage'"
  end

  def down
    now = Time.current
    execute <<~SQL.squish
      INSERT INTO permissions (key, name, description, created_at, updated_at)
      VALUES ('roles.manage', 'Kelola roles', 'Membuat, mengubah, dan menghapus role serta permission.', #{connection.quote(now)}, #{connection.quote(now)})
      ON CONFLICT (key) DO NOTHING
    SQL
    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT DISTINCT existing.role_id, legacy.id, #{connection.quote(now)}, #{connection.quote(now)}
      FROM role_permissions existing
      INNER JOIN permissions granular ON granular.id = existing.permission_id
      CROSS JOIN permissions legacy
      WHERE granular.key IN ('roles.create', 'roles.update', 'roles.delete') AND legacy.key = 'roles.manage'
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL
    execute <<~SQL.squish
      DELETE FROM role_permissions
      WHERE permission_id IN (SELECT id FROM permissions WHERE key IN ('roles.create', 'roles.update', 'roles.delete'))
    SQL
    execute "DELETE FROM permissions WHERE key IN ('roles.create', 'roles.update', 'roles.delete')"
  end
end
