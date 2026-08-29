class AddOperationsPermissions < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "jobs.view" => [ "Lihat antrean job", "Melihat status antrean dan job gagal." ],
    "jobs.update" => [ "Kelola job gagal", "Mencoba ulang atau menghapus job gagal." ],
    "api_docs.view" => [ "Lihat dokumentasi API", "Membuka dokumentasi OpenAPI interaktif." ]
  }.freeze

  def up
    PERMISSIONS.each do |key, (name, description)|
      Permission.find_or_create_by!(key: key) { |permission| permission.assign_attributes(name: name, description: description) }
    end
    admin = Role.find_by(key: "admin")
    admin.permissions |= Permission.where(key: PERMISSIONS.keys) if admin
  end

  def down
    Permission.where(key: PERMISSIONS.keys).destroy_all
  end
end
