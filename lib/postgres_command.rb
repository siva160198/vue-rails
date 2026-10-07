require "uri"

class PostgresCommand
  def self.run(tool, arguments, database_url:)
    uri = URI(database_url)
    raise ArgumentError, "Expected PostgreSQL URL" unless %w[postgres postgresql].include?(uri.scheme)
    environment = {}
    if uri.password
      environment["PGPASSWORD"] = URI::DEFAULT_PARSER.unescape(uri.password)
      uri.password = nil
    end
    query = uri.query.to_s.split("&").map { |pair| pair.split("=", 2).map { |value| URI::DEFAULT_PARSER.unescape(value) } }
    query.reject! do |key, value|
      environment["PGPASSWORD"] = value if key == "password"
      key == "password"
    end
    uri.query = query.empty? ? nil : URI.encode_www_form(query).gsub("+", "%20")
    system(environment, tool, *arguments, uri.to_s)
  end
end
