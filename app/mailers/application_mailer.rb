class ApplicationMailer < ActionMailer::Base
  self.delivery_job = MailDeliveryJob
  default from: ENV.fetch("MAILER_FROM", "no-reply@example.com")
  layout "mailer"
end
