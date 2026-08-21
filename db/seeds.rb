# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
if Rails.env.development?
  admin = User.find_or_initialize_by(email_address: ENV.fetch("ADMIN_EMAIL", "admin@tourplan.local"))

  if admin.new_record?
    admin.password = ENV.fetch("ADMIN_PASSWORD") do
      raise "Set ADMIN_PASSWORD when creating the development admin"
    end
  end

  admin.role = :admin
  admin.save!

  puts "Development admin ready: #{admin.email_address}"
end
