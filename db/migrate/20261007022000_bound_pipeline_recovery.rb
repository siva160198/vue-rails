class BoundPipelineRecovery < ActiveRecord::Migration[8.1]
  def change
    add_column :import_runs, :recovery_attempts, :integer, default: 0, null: false
    add_column :integration_connections, :recovery_attempts, :integer, default: 0, null: false
    add_index :integration_items, :updated_at
  end
end
