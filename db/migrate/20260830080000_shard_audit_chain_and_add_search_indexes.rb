class ShardAuditChainAndAddSearchIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    add_column :audit_logs, :chain_key, :string, default: "legacy", null: false unless column_exists?(:audit_logs, :chain_key)
    add_index :audit_logs, [ :chain_key, :id ], algorithm: :concurrently unless index_exists?(:audit_logs, [ :chain_key, :id ])

    add_trigram_index :users, :email_address
    %i[name key description].each { |column| add_trigram_index :roles, column }
    %i[action auditable_type ip_address].each { |column| add_trigram_index :audit_logs, column }
    add_index :audit_logs, "((metadata ->> 'email_digest'))", name: "index_audit_logs_on_email_digest_metadata", algorithm: :concurrently,
      where: "action = 'session.login_failed'" unless index_exists?(:audit_logs, name: "index_audit_logs_on_email_digest_metadata")
  end

  def down
    remove_index :audit_logs, name: "index_audit_logs_on_email_digest_metadata", algorithm: :concurrently, if_exists: true
    %w[index_users_on_email_address_trigram index_roles_on_name_trigram index_roles_on_key_trigram index_roles_on_description_trigram index_audit_logs_on_action_trigram index_audit_logs_on_auditable_type_trigram index_audit_logs_on_ip_address_trigram].each do |name|
      remove_index name.start_with?("index_users") ? :users : name.start_with?("index_roles") ? :roles : :audit_logs, name: name, algorithm: :concurrently, if_exists: true
    end
    remove_index :audit_logs, column: [ :chain_key, :id ], algorithm: :concurrently, if_exists: true
    remove_column :audit_logs, :chain_key, if_exists: true
  end

  private
    def add_trigram_index(table, column)
      name = "index_#{table}_on_#{column}_trigram"
      return if index_exists?(table, name: name)

      add_index table, column, using: :gin, opclass: :gin_trgm_ops, name: name, algorithm: :concurrently
    end
end
