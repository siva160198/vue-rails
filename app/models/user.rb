class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :login_challenges, dependent: :destroy

  enum :role, { member: "member", admin: "admin" }, default: :member, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true
end
