class AddAdminDualControl < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "security_approvals.view" => [ "Lihat persetujuan keamanan", "View security approvals" ],
    "security_approvals.update" => [ "Setujui perubahan keamanan", "Approve security changes" ]
  }.freeze

  def up
    create_table :admin_approvals, id: :uuid do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :approver, foreign_key: { to_table: :users }
      t.string :action_key, null: false
      t.string :payload_digest, null: false
      t.jsonb :payload_summary, null: false, default: {}
      t.datetime :approved_at
      t.datetime :consumed_at
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :admin_approvals, %i[action_key payload_digest requester_id], name: "index_admin_approvals_lookup"
    add_index :admin_approvals, :expires_at

    now = Time.current
    admin = Role.find_by(key: "admin")
    PERMISSIONS.each do |key, names|
      permission = Permission.find_or_create_by!(key: key) do |record|
        record.name = names.first
        record.description = names.last
        record.created_at = now
        record.updated_at = now
      end
      admin&.permissions << permission unless admin&.permissions&.exists?(permission.id)
    end
  end

  def down
    keys = PERMISSIONS.keys
    RolePermission.where(permission_id: Permission.where(key: keys)).delete_all
    Permission.where(key: keys).delete_all
    drop_table :admin_approvals
  end
end
