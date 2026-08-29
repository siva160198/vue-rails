module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      session = Session.includes(:user).find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
      session if session&.user&.active?
    end

    def request_authentication
      if request.format.json?
        render_api_error("AUTHENTICATION_REQUIRED", status: :unauthorized)
      else
        session[:return_to_after_authenticating] = request.url
        redirect_to "/login"
      end
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      enforce_session_limit_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
        LoginNotificationMailer.with(user: user, session: session).new_login.deliver_later
      end
    end

    def enforce_session_limit_for(user)
      maximum = Integer(ENV.fetch("MAX_ACTIVE_SESSIONS", "10"), 10).clamp(1, 100)
      excess_ids = user.sessions.order(updated_at: :desc).offset(maximum - 1).ids
      user.sessions.where(id: excess_ids).delete_all
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
