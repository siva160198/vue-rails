class LoginOtpMailer < ApplicationMailer
  def verification_code
    @user = params[:user]
    @code = params[:code]

    mail(to: @user.email_address, subject: "Kode verifikasi login Anda")
  end
end
