# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
Role.find_or_create_by!(key: "admin") { |role| role.assign_attributes(name: "Administrator", description: "Akses penuh ke seluruh admin panel.", system: true) }
Role.find_or_create_by!(key: "member") { |role| role.assign_attributes(name: "Member", description: "Role bawaan untuk pengguna yang melakukan registrasi.", system: true) }

permissions = {
  "dashboard.view" => [ "Dashboard", "Melihat dashboard admin." ],
  "users.view" => [ "Lihat users", "Melihat daftar dan detail user." ],
  "users.update" => [ "Ubah users", "Mengubah role dan status user." ],
  "roles.view" => [ "Lihat roles", "Melihat daftar role dan permission." ],
  "roles.manage" => [ "Kelola roles", "Membuat, mengubah, dan menghapus role serta permission." ],
  "audit_logs.view" => [ "Lihat audit logs", "Melihat riwayat aktivitas keamanan." ]
}
permissions.each do |key, (name, description)|
  Permission.find_or_create_by!(key: key) { |permission| permission.assign_attributes(name: name, description: description) }
end
Role.find_by!(key: "admin").permissions = Permission.all

if Rails.env.development?
  admin = User.find_or_initialize_by(email_address: ENV.fetch("ADMIN_EMAIL", "admin@tourplan.local"))

  if admin.new_record?
    admin.password = ENV.fetch("ADMIN_PASSWORD") do
      raise "Set ADMIN_PASSWORD when creating the development admin"
    end
  end

  admin.role = "admin"
  admin.email_verified_at ||= Time.current
  admin.save!

  puts "Development admin ready: #{admin.email_address}"
end
