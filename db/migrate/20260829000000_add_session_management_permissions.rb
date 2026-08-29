class AddSessionManagementPermissions < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "sessions.view" => [ "Lihat perangkat", "Melihat perangkat dan sesi login milik sendiri." ],
    "sessions.delete" => [ "Hapus sesi", "Mengakhiri sesi login milik sendiri." ]
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
      SELECT roles.id, permissions.id, #{connection.quote(now)}, #{connection.quote(now)}
      FROM roles CROSS JOIN permissions WHERE permissions.key IN ('sessions.view', 'sessions.delete')
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM permissions WHERE key IN ('sessions.view', 'sessions.delete')"
  end
end
