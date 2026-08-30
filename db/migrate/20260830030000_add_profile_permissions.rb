class AddProfilePermissions < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "profile.view" => [ "Lihat profil", "Melihat profil akun sendiri." ],
    "profile.update" => [ "Ubah profil", "Mengubah foto dan informasi profil akun sendiri." ]
  }.freeze

  def up
    PERMISSIONS.each do |key, (name, description)|
      Permission.find_or_create_by!(key: key) { |permission| permission.assign_attributes(name: name, description: description) }
    end
    Permission.where(key: PERMISSIONS.keys).find_each do |permission|
      Role.find_each { |role| role.permissions << permission unless role.permission_ids.include?(permission.id) }
    end
  end

  def down
    Permission.where(key: PERMISSIONS.keys).destroy_all
  end
end
