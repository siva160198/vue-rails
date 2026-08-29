require "json"

class StructuredLogFormatter < Logger::Formatter
  TAG_PATTERN = /\A(?:\[([^\]]+)\] )+/.freeze

  def call(severity, time, program_name, message)
    text = message.is_a?(String) ? message : message.inspect
    tags = text[TAG_PATTERN].to_s.scan(/\[([^\]]+)\]/).flatten
    text = text.sub(TAG_PATTERN, "")
    payload = {
      timestamp: time.utc.iso8601(6),
      severity: severity,
      message: text
    }
    payload[:request_id] = tags.first if tags.first
    payload[:program] = program_name if program_name
    "#{JSON.generate(payload)}\n"
  end
end
