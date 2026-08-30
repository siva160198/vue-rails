require "net/http"

class CompromisedPasswordChecker
  TIMEOUT = 2

  def self.compromised?(password)
    return false unless ENV.fetch("PASSWORD_BREACH_CHECK_ENABLED", "false") == "true"

    digest = Digest::SHA1.hexdigest(password).upcase
    prefix, suffix = digest[0, 5], digest[5..]
    response = Net::HTTP.start("api.pwnedpasswords.com", 443, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      request = Net::HTTP::Get.new("/range/#{prefix}", "Add-Padding" => "true", "User-Agent" => "vue-rails-security-check")
      http.request(request)
    end
    response.is_a?(Net::HTTPSuccess) && response.body.each_line.any? { |line| line.start_with?("#{suffix}:") }
  rescue IOError, SocketError, SystemCallError, Timeout::Error
    false
  end
end
