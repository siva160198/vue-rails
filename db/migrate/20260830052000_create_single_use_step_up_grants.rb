class CreateSingleUseStepUpGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :step_up_grants, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true
      t.string :purpose, null: false
      t.integer :authentication_version, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :step_up_grants, :expires_at
  end
end
