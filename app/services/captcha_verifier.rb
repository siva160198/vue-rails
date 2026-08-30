require "net/http"

class CaptchaVerifier
  ENDPOINT = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

  def self.enabled?
    ENV["TURNSTILE_SITE_KEY"].present? && ENV["TURNSTILE_SECRET_KEY"].present?
  end

  def self.site_key
    ENV["TURNSTILE_SITE_KEY"] if enabled?
  end

  def self.verify(token:, remote_ip:)
    return true unless enabled?
    return false if token.blank? || token.bytesize > 2_048

    request = Net::HTTP::Post.new(ENDPOINT)
    request.set_form_data(secret: ENV.fetch("TURNSTILE_SECRET_KEY"), response: token, remoteip: remote_ip, idempotency_key: SecureRandom.uuid)
    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 2, read_timeout: 3) { |http| http.request(request) }
    return false unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    expected_hostname = ENV["TURNSTILE_EXPECTED_HOSTNAME"].presence || ENV["APP_HOST"].presence
    payload.fetch("success", false) && payload["action"] == "login" && (expected_hostname.nil? || payload["hostname"] == expected_hostname)
  rescue JSON::ParserError, KeyError, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError
    false
  end
end
