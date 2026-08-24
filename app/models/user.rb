class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :login_challenges, dependent: :destroy

  enum :role, { member: "member", admin: "admin" }, default: :member, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  def email_verified?
    email_verified_at.present?
  end
end
