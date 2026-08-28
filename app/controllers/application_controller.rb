class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  around_action :switch_locale

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: "Anda tidak memiliki izin untuk mengakses resource ini." }, status: :forbidden
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "Sesi keamanan tidak valid. Muat ulang halaman dan coba lagi." }, status: :unprocessable_content
  end

  private
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
