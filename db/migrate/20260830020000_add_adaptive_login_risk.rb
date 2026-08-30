class AddAdaptiveLoginRisk < ActiveRecord::Migration[8.1]
  def change
    change_table :login_attempts, bulk: true do |t|
      t.string :device_digest
      t.integer :risk_score, null: false, default: 0
      t.boolean :captcha_verified, null: false, default: false
    end
    add_index :login_attempts, %i[device_digest created_at]
    add_column :users, :security_alerted_at, :datetime
  end
end
