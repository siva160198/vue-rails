class OperationsMonitorJob < ApplicationJob
  queue_as :maintenance
  def perform
    return unless ENV.fetch("OPERATIONS_MONITOR_ENABLED", "false") == "true"
    result = Operations::HealthCheck.new.call
    result[:checks].each do |name, healthy|
      next if healthy
      # Minimal safe events are forwarded by the optional external log collector.
      key = "operations-alert:v1:#{name}"
      next unless Rails.cache.write(key, true, expires_in: 15.minutes, unless_exist: true)
      Rails.logger.error({ event: "operational_alert", code: "#{name.to_s.upcase}_UNHEALTHY" }.to_json)
    end
  end
end
