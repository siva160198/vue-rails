class LoginNotificationMailer < ApplicationMailer
  def new_login
    @user = params[:user]
    @session = params[:session]
    mail(to: @user.email_address, subject: I18n.t("mailers.login_notification.subject"))
  end
end
