class WebauthnCredential < ApplicationRecord
  belongs_to :user
  validates :external_id, :public_key, :nickname, presence: true
  validates :external_id, uniqueness: true
  validates :nickname, length: { maximum: 50 }
  validates :authenticator_attachment, inclusion: { in: %w[platform cross-platform] }, allow_blank: true
end
