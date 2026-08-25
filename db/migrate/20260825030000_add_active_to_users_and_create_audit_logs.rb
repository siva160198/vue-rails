class AddActiveToUsersAndCreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active, :boolean, null: false, default: true

    create_table :audit_logs do |t|
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, :action
    add_index :audit_logs, %i[auditable_type auditable_id]
    add_index :audit_logs, :created_at
  end
end
