class ExpandEncryptedPhoneStorage < ActiveRecord::Migration[8.1]
  def change
    change_column :users, :phone, :text
  end
end
