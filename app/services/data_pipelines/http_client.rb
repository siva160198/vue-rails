require "net/http"
require "resolv"
require "ipaddr"

module DataPipelines
  class HttpClient
    MAX_BYTES = 1.megabyte
    BLOCKED_NETWORKS = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 2001:db8::/32].map { |range| IPAddr.new(range) }.freeze
    def initialize(origin:, allowed_hosts:)
      @origin = URI(origin)
      raise ArgumentError, "Unapproved origin" unless @origin.is_a?(URI::HTTPS) && allowed_hosts.include?(@origin.host) && @origin.port == 443 && @origin.userinfo.nil? && @origin.path.in?([ "", "/" ]) && @origin.query.nil? && @origin.fragment.nil?
    end

    def get(path, headers: {})
      uri = URI.join(@origin.to_s, path)
      raise ArgumentError, "Unapproved destination" unless uri.host == @origin.host && uri.port == 443 && uri.scheme == "https" && uri.userinfo.nil?
      addresses = Resolv::DNS.open do |resolver|
        resolver.timeouts = 2
        resolver.getaddresses(uri.host).map(&:to_s)
      end
      raise ArgumentError, "Non-public destination" if addresses.empty? || addresses.any? { |address| self.class.blocked?(address) }
      http = Net::HTTP.new(uri.host, 443, nil) # Do not silently route through environment proxies.
      http.ipaddr = addresses.first # Pin the checked address, retaining the TLS hostname.
      http.use_ssl = true
      http.open_timeout = 2
      http.read_timeout = 5
      http.write_timeout = 5
      http.max_retries = 0
      body = +""
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      http.request(Net::HTTP::Get.new(uri.request_uri, headers)) do |response|
        raise Sync::AuthenticationExpired if response.code.in?(%w[401 403])
        raise Sync::TransientFailure.new(retry_after: Integer(response["Retry-After"], exception: false) || 30) if response.code == "429" || response.code.to_i >= 500
        raise ArgumentError, "Unexpected provider response" unless response.code == "200" # Never follow redirects.
        response.read_body do |chunk|
          body << chunk
          raise ArgumentError, "Provider response too large" if body.bytesize > MAX_BYTES
          raise Sync::TransientFailure if Process.clock_gettime(Process::CLOCK_MONOTONIC) - started > 10
        end
      end
      JSON.parse(body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError
      raise Sync::TransientFailure
    end

    def self.blocked?(address)
      ip = IPAddr.new(address)
      ip = ip.native if ip.ipv4_mapped?
      BLOCKED_NETWORKS.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end
  end
end
