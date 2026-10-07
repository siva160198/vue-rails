class WebauthnCredential < ApplicationRecord
  belongs_to :user
  after_create :invalidate_device_trust
  after_destroy :invalidate_device_trust
  validates :external_id, :public_key, :nickname, presence: true
  validates :external_id, uniqueness: true
  validates :nickname, length: { maximum: 50 }
  validates :authenticator_attachment, inclusion: { in: %w[platform cross-platform] }, allow_blank: true

  private
    def invalidate_device_trust
      user.increment!(:authentication_version)
      user.trusted_devices.where("expires_at > ?", Time.current).update_all(expires_at: Time.current)
    end
end
