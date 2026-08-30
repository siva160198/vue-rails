class LoginAttempt < ApplicationRecord
  validates :email_digest, :ip_address, presence: true
end
