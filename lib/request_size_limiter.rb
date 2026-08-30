class RequestSizeLimiter
  JSON_LIMIT = 1.megabyte
  AVATAR_LIMIT = 12.megabytes

  def initialize(app)
    @app = app
  end

  def call(env)
    limit = avatar_request?(env) ? AVATAR_LIMIT : JSON_LIMIT
    length = env["CONTENT_LENGTH"].to_i
    return payload_too_large(env) if length > limit

    env["rack.input"] = LimitedInput.new(env.fetch("rack.input"), limit) if env["rack.input"]
    @app.call(env)
  rescue PayloadTooLarge
    payload_too_large(env)
  end

  class PayloadTooLarge < StandardError; end

  class LimitedInput
    def initialize(input, limit)
      @input = input
      @limit = limit
      @bytes_read = 0
    end

    def read(length = nil, buffer = nil)
      chunk = @input.read(length, buffer)
      track!(chunk)
    end

    def gets(*arguments)
      chunk = @input.gets(*arguments)
      track!(chunk)
    end

    def each
      return enum_for(:each) unless block_given?

      while (chunk = gets)
        yield chunk
      end
    end

    def rewind
      @input.rewind
      @bytes_read = 0
    end

    def method_missing(name, *arguments, &block)
      @input.public_send(name, *arguments, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @input.respond_to?(name, include_private) || super
    end

    private
      def track!(chunk)
        return chunk unless chunk

        @bytes_read += chunk.bytesize
        raise PayloadTooLarge if @bytes_read > @limit

        chunk
      end
  end

  private
    def avatar_request?(env)
      env["PATH_INFO"] == "/api/v1/profile" && env["REQUEST_METHOD"] == "PATCH" && env["CONTENT_TYPE"].to_s.start_with?("multipart/form-data")
    end

    def payload_too_large(env)
      requested = env["HTTP_ACCEPT_LANGUAGE"].to_s.split(/[-,]/).first
      locale = I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
      body = I18n.with_locale(locale) do
        { error: { code: "PAYLOAD_TOO_LARGE", message: I18n.t("api.errors.payload_too_large"), details: {} } }.to_json
      end
      [ 413, { "content-type" => "application/json; charset=utf-8", "content-length" => body.bytesize.to_s }, [ body ] ]
    end
end
