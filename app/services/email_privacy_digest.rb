class EmailPrivacyDigest
  def self.call(email_address)
    OpenSSL::HMAC.hexdigest("SHA256", key, email_address.to_s.strip.downcase)
  end

  def self.legacy(email_address)
    Digest::SHA256.hexdigest(email_address.to_s.strip.downcase)
  end

  def self.key
    Rails.application.key_generator.generate_key("login-email-digest", 32)
  end
  private_class_method :key
end
