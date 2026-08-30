require "net/smtp"

class MailDeliveryJob < ActionMailer::MailDeliveryJob
  queue_as :mailers

  retry_on Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy,
    Net::SMTPUnknownError, wait: :polynomially_longer, attempts: 4
  discard_on ActiveJob::DeserializationError
end
