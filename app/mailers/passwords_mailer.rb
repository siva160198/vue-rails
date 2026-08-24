class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    @reset_url = "#{frontend_url}/reset-password?token=#{ERB::Util.url_encode(user.password_reset_token)}"
    mail subject: "Link reset password Anda", to: user.email_address
  end
end
