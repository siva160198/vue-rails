class SecurityEncryptor
  PREFIX = "enc:v1:".freeze

  def self.encrypt(value, purpose:)
    return if value.nil?
    return value if value.start_with?(PREFIX)

    PREFIX + encryptor(purpose).encrypt_and_sign(value)
  end

  def self.decrypt(value, purpose:)
    return value unless value&.start_with?(PREFIX)

    encryptor(purpose).decrypt_and_verify(value.delete_prefix(PREFIX))
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.encryptor(purpose)
    secret = Rails.application.key_generator.generate_key("security-field:#{purpose}", 32)
    ActiveSupport::MessageEncryptor.new(secret)
  end
  private_class_method :encryptor
end
