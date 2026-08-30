class SecurityNotificationMailer < ApplicationMailer
  def password_changed
    @user = params[:user]
    @security_url = security_url
    mail(to: @user.email_address, subject: I18n.t("mailers.security.password_changed_subject"))
  end

  def email_changed
    @user = params[:user]
    @revert_url = "#{frontend_url}/email-revert?token=#{ERB::Util.url_encode(params[:revert_token])}"
    mail(to: params[:previous_email], subject: I18n.t("mailers.security.email_changed_subject"))
  end

  def suspicious_login
    @user = params[:user]
    @ip_address = params[:ip_address]
    @user_agent = params[:user_agent]
    @security_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/forgot-password?security=1"
    mail(to: @user.email_address, subject: I18n.t("mailers.security.suspicious_login_subject"))
  end

  def security_setting_changed
    @user = params[:user]
    @security_event = params[:security_event]
    @security_url = security_url
    mail(to: @user.email_address, subject: I18n.t("mailers.security.setting_changed_subject"))
  end

  private
    def frontend_url
      ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    end

    def security_url
      "#{frontend_url}/forgot-password?security=1"
    end
end
