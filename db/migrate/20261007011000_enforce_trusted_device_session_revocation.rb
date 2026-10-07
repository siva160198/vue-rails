class EnforceTrustedDeviceSessionRevocation < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :sessions, :trusted_devices, on_delete: :nullify
    add_foreign_key :sessions, :trusted_devices, on_delete: :cascade
  end
end
