abort "E2E setup requires its dedicated test database" unless Rails.env.test? && ENV["E2E"] == "true" && User.connection_db_config.database.end_with?("_e2e")

admin = User.find_or_initialize_by(email_address: ENV.fetch("E2E_ADMIN_EMAIL"))
# The password-reset scenario changes this fixture on every run. Reset ONLY its
# test history so repeat E2E runs can restore the known credential without weakening
# the production password-reuse policy.
admin.password_histories.delete_all if admin.persisted?
admin.assign_attributes(
  password: ENV.fetch("E2E_ADMIN_PASSWORD"),
  password_confirmation: ENV.fetch("E2E_ADMIN_PASSWORD"),
  role: :admin,
  email_verified_at: Time.current,
  active: true,
  login_otp_required: true,
  failed_login_attempts: 0,
  locked_until: nil
)
admin.save!
admin.sessions.destroy_all
admin.login_challenges.destroy_all
admin.trusted_devices.destroy_all

member_role = Role.find_by!(key: "member")
member_role.permissions = Permission.where(key: %w[sessions.view sessions.delete])
