if ENV["WEBAUTHN_RP_ID"].present? && ENV["WEBAUTHN_ORIGIN"].present?
  WebAuthn.configure do |config|
    config.origin = ENV.fetch("WEBAUTHN_ORIGIN")
    config.rp_id = ENV.fetch("WEBAUTHN_RP_ID")
    config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "Vue Rails")
  end
end
