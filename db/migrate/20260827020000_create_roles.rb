class CreateRoles < ActiveRecord::Migration[8.1]
  def up
    create_table :roles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system, null: false, default: false
      t.timestamps
    end

    add_index :roles, :key, unique: true

    now = Time.current
    execute <<~SQL.squish
      INSERT INTO roles (key, name, description, system, created_at, updated_at)
      VALUES
        ('admin', 'Administrator', 'Akses penuh ke seluruh admin panel.', TRUE, '#{now.to_fs(:db)}', '#{now.to_fs(:db)}'),
        ('member', 'Member', 'Role bawaan untuk pengguna yang melakukan registrasi.', TRUE, '#{now.to_fs(:db)}', '#{now.to_fs(:db)}')
    SQL

    add_foreign_key :users, :roles, column: :role, primary_key: :key
  end

  def down
    remove_foreign_key :users, column: :role
    drop_table :roles
  end
end
