class AddOptionalDataPipelines < ActiveRecord::Migration[8.1]
  def change
    create_table :import_runs do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :adapter_key, null: false
      t.string :status, null: false, default: "queued"
      t.string :failure_code
      t.text :source_ciphertext
      t.string :source_digest, null: false
      t.string :submission_key, null: false
      t.integer :total_rows, null: false, default: 0
      t.integer :processed_rows, null: false, default: 0
      t.integer :failed_rows, null: false, default: 0
      t.datetime :heartbeat_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :import_runs, [ :owner_id, :adapter_key, :submission_key ], unique: true
    add_index :import_runs, [ :status, :updated_at ]
    create_table :import_rows do |t|
      t.references :import_run, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :status, null: false, default: "pending"
      t.string :failure_code
      t.text :payload_ciphertext
      t.timestamps
    end
    add_index :import_rows, [ :import_run_id, :position ], unique: true
    add_index :import_rows, [ :import_run_id, :status, :position ]
    create_table :integration_connections do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :provider_key, null: false
      t.text :credentials_ciphertext, null: false
      t.text :cursor_ciphertext
      t.string :status, null: false, default: "idle"
      t.string :failure_code
      t.integer :attempts, null: false, default: 0
      t.integer :processed_items, null: false, default: 0
      t.datetime :next_sync_at
      t.datetime :heartbeat_at
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :integration_connections, [ :status, :next_sync_at ]
    create_table :integration_items do |t|
      t.references :integration_connection, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id, null: false
      t.text :payload_ciphertext, null: false
      t.timestamps
    end
    add_index :integration_items, [ :integration_connection_id, :external_id ], unique: true, name: "index_integration_items_on_connection_and_external_id"
  end
end
