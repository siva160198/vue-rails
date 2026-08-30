require "base64"
require "openssl"
require "uri"

class TotpAuthenticator
  PERIOD = 30
  DIGITS = 6
  WINDOW = 1

  def self.generate_secret
    Base64.strict_encode64(SecureRandom.random_bytes(20))
  end

  def self.code(secret, at: Time.current)
    counter = at.to_i / PERIOD
    digest = OpenSSL::HMAC.digest("SHA1", Base64.strict_decode64(secret), [ counter ].pack("Q>"))
    offset = digest.getbyte(-1) & 0x0f
    binary = digest.byteslice(offset, 4).unpack1("N") & 0x7fffffff
    format("%0#{DIGITS}d", binary % (10**DIGITS))
  end

  def self.valid?(secret, submitted, at: Time.current)
    return false unless submitted.to_s.match?(/\A\d{6}\z/)

    (-WINDOW..WINDOW).any? do |offset|
      ActiveSupport::SecurityUtils.secure_compare(code(secret, at: at + offset * PERIOD), submitted.to_s)
    end
  rescue ArgumentError
    false
  end

  def self.provisioning_uri(secret:, email:, issuer:)
    label = ERB::Util.url_encode("#{issuer}:#{email}")
    query = URI.encode_www_form(secret: base32_secret(secret), issuer: issuer, algorithm: "SHA1", digits: DIGITS, period: PERIOD)
    "otpauth://totp/#{label}?#{query}"
  end


  def self.base32_secret(secret)
    base32(Base64.strict_decode64(secret))
  end

  def self.base32(bytes)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    bits = bytes.unpack1("B*")
    bits.scan(/.{1,5}/).map { |chunk| alphabet[chunk.ljust(5, "0").to_i(2)] }.join
  end
  private_class_method :base32
end
