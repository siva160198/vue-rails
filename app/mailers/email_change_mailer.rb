class EmailChangeMailer < ApplicationMailer
  def verification_code
    @code = params[:code]
    @expires_in = EmailChangeChallenge::LIFETIME.in_minutes.to_i
    mail(to: params[:email_address], subject: I18n.t("mailers.email_change.subject"))
  end
end
