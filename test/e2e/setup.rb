admin = User.find_or_initialize_by(email_address: ENV.fetch("E2E_ADMIN_EMAIL"))
admin.assign_attributes(
  password: ENV.fetch("E2E_ADMIN_PASSWORD"),
  password_confirmation: ENV.fetch("E2E_ADMIN_PASSWORD"),
  role: :admin,
  email_verified_at: Time.current
)
admin.save!
admin.sessions.destroy_all
admin.login_challenges.destroy_all
