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
  "roles.create" => [ "Buat role", "Membuat role baru dan menetapkan permission awal." ],
  "roles.update" => [ "Ubah role", "Mengubah nama, deskripsi, dan permission role." ],
  "roles.delete" => [ "Hapus role", "Menghapus role kustom yang tidak digunakan." ],
  "audit_logs.view" => [ "Lihat audit logs", "Melihat riwayat aktivitas keamanan." ],
  "sessions.view" => [ "Lihat perangkat", "Melihat perangkat dan sesi login milik sendiri." ],
  "sessions.delete" => [ "Hapus sesi", "Mengakhiri sesi login milik sendiri." ],
  "jobs.view" => [ "Lihat antrean job", "Melihat status antrean dan job gagal." ],
  "jobs.update" => [ "Kelola job gagal", "Mencoba ulang atau menghapus job gagal." ],
  "api_docs.view" => [ "Lihat dokumentasi API", "Membuka dokumentasi OpenAPI interaktif." ]
}
permissions.each do |key, (name, description)|
  Permission.find_or_initialize_by(key: key).tap do |permission|
    permission.update!(name: name, description: description)
  end
end
Permission.where(key: "roles.manage").destroy_all
Role.find_by!(key: "admin").permissions = Permission.all
session_permissions = Permission.where(key: %w[sessions.view sessions.delete])
Role.where.not(key: "admin").find_each { |role| role.permissions |= session_permissions }

if Rails.env.development?
  admin = User.find_or_initialize_by(email_address: ENV.fetch("ADMIN_EMAIL", "admin@vue_rails.local"))

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
