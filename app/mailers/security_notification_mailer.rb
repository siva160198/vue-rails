class SecurityNotificationMailer < ApplicationMailer
  def password_changed
    @user = params[:user]
    mail(to: @user.email_address, subject: I18n.t("mailers.security.password_changed_subject"))
  end
end
