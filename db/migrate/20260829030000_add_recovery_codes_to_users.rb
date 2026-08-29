class AddRecoveryCodesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :recovery_code_digests, :jsonb, null: false, default: []
  end
end
