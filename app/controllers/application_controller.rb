class ApplicationController < ActionController::Base
  include Authentication
  include StepUpAuthentication
  include AdminDualControl
  include ApiPagination
  include Pundit::Authorization
  around_action :switch_locale

  rescue_from StandardError do |error|
    raise error unless request.path.start_with?("/api/")

    Rails.error.report(error, handled: true, severity: :error, context: { request_id: request.request_id })
    render_api_error("INTERNAL_SERVER_ERROR", status: :internal_server_error)
  end
  rescue_from Pundit::NotAuthorizedError do
    render_api_error("FORBIDDEN", status: :forbidden)
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render_api_error("INVALID_CSRF_TOKEN", status: :unprocessable_content)
  end
  rescue_from ActiveRecord::RecordNotFound do
    render_api_error("RESOURCE_NOT_FOUND", status: :not_found)
  end
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_api_error("INVALID_JSON", status: :bad_request)
  end
  rescue_from ApiPagination::InvalidCursor do
    render_api_error("INVALID_PAGINATION_CURSOR", status: :bad_request)
  end

  private
    def render_api_error(code, status:, details: {}, message: nil, **interpolations)
      render json: {
        error: {
          code: code,
          message: message || I18n.t("api.errors.#{code.downcase}", **interpolations),
          details: details || {}
        }
      }, status: status
    end

    def render_validation_error(record)
      render_api_error(
        "VALIDATION_FAILED",
        status: :unprocessable_content,
        details: record.errors.to_hash
      )
    end

    def switch_locale(&action)
      requested = request.headers["Accept-Language"].to_s.split(/[-,]/).first
      locale = I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
      I18n.with_locale(locale, &action)
    end

    def pundit_user
      Current.user
    end
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
