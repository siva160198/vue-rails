class DropPasswordResetChallenges < ActiveRecord::Migration[8.1]
  def change
    drop_table :password_reset_challenges do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.integer :attempts_count, null: false, default: 0
      t.datetime :consumed_at

      t.timestamps
      t.index :expires_at
    end
  end
end
