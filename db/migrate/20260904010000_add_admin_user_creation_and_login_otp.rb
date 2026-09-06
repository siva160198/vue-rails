class AddAdminUserCreationAndLoginOtp < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :login_otp_required, :boolean, null: false, default: true
    add_column :users, :invited_at, :datetime
    add_column :users, :invitation_accepted_at, :datetime

    now = Time.current
    execute <<~SQL.squish
      INSERT INTO permissions (key, name, description, created_at, updated_at)
      VALUES ('users.create', 'Buat user', 'Membuat user dan mengirim link untuk membuat password.', #{connection.quote(now)}, #{connection.quote(now)})
      ON CONFLICT (key) DO UPDATE
      SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = EXCLUDED.updated_at
    SQL
    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, #{connection.quote(now)}, #{connection.quote(now)}
      FROM roles CROSS JOIN permissions
      WHERE roles.key = 'admin' AND permissions.key = 'users.create'
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM role_permissions WHERE permission_id IN (SELECT id FROM permissions WHERE key = 'users.create')"
    execute "DELETE FROM permissions WHERE key = 'users.create'"
    remove_column :users, :invitation_accepted_at
    remove_column :users, :invited_at
    remove_column :users, :login_otp_required
  end
end
