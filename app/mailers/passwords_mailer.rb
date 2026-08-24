class PasswordsMailer < ApplicationMailer
  def reset(user, code)
    @user = user
    @code = code
    mail subject: "Kode reset password Anda", to: user.email_address
  end
end
