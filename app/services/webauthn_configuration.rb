module WebauthnConfiguration
  module_function

  def enabled?
    ENV["WEBAUTHN_RP_ID"].present? && ENV["WEBAUTHN_ORIGIN"].present?
  end
end
