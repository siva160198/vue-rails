require "ipaddr"

module TrustedLoginNetworks
  module_function

  def include?(address)
    ip = IPAddr.new(address)
    networks.any? { |network| network.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def networks
    ENV.fetch("TRUSTED_LOGIN_NETWORKS", "").split(",").filter_map do |value|
      IPAddr.new(value.strip) if value.strip.present?
    end
  rescue IPAddr::InvalidAddressError
    []
  end
end
