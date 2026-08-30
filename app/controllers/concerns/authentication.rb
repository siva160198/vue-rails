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
      return unless session
      if session.expired? || !session.user.active?
        AuditLog.record!(action: "session.expired", actor: session.user, auditable: session.user, request: request) if session.expired?
        session.destroy!
        cookies.delete(:session_id)
        return
      end

      session.touch_activity!
      session
    end

    def request_authentication
      if request.path.start_with?("/api/")
        render_api_error("AUTHENTICATION_REQUIRED", status: :unauthorized)
      else
        session[:return_to_after_authenticating] = request.url
        redirect_to "/login"
      end
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user, notify: true)
      enforce_session_limit_for(user)
      now = Time.current
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip, last_seen_at: now, expires_at: Session.absolute_lifetime_for(user).from_now).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?,
          expires: session.expires_at
        }
        LoginNotificationMailer.with(user: user, session: session).new_login.deliver_later if notify
      end
    end

    def enforce_session_limit_for(user)
      maximum = Integer(ENV.fetch("MAX_ACTIVE_SESSIONS", "10"), 10).clamp(1, 100)
      excess_ids = user.sessions.order(updated_at: :desc).offset(maximum - 1).ids
      user.sessions.where(id: excess_ids).delete_all
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_id)
    end

    def rotate_current_session!
      previous = Current.session
      start_new_session_for(Current.user, notify: false)
      previous&.destroy!
      AuditLog.record!(action: "session.rotated", actor: Current.user, auditable: Current.user, request: request)
      Current.session
    end

    def invalidate_authentication_trust!
      Current.user.increment!(:authentication_version)
      cookies.delete(:otp_trust)
    end
end
