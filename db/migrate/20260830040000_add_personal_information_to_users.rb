class AddPersonalInformationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_name, :string, limit: 80
    add_column :users, :last_name, :string, limit: 80
    add_column :users, :phone, :string, limit: 30
  end
end
