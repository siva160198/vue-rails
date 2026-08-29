module Api
  module V1
    class SessionsController < ApplicationController
      allow_unauthenticated_access only: %i[create verify_otp resend_otp]
      rate_limit to: 10, within: 3.minutes, only: %i[create verify_otp resend_otp],
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def show
        render json: { user: user_json(Current.user) }
      end

      def create
        user = User.authenticate_by(params.permit(:email_address, :password))
        if user && !user.active?
          render_inactive_account
        elsif user
          if otp_trusted_for?(user)
            start_new_session_for(user)
            AuditLog.record!(action: "session.login", actor: user, auditable: user, request: request)
            return render json: { otp_required: false, user: user_json(user) }, status: :created
          end
          challenge, code = LoginChallenge.issue_for!(user)
          LoginOtpMailer.with(user: user, code: code).verification_code.deliver_later
          render json: challenge_json(challenge), status: :accepted
        else
          AuditLog.record!(action: "session.login_failed", metadata: { email_digest: Digest::SHA256.hexdigest(params[:email_address].to_s.downcase) }, request: request)
          render_api_error("INVALID_CREDENTIALS", status: :unauthorized)
        end
      end

      def verify_otp
        challenge = find_challenge
        return render_invalid_challenge unless challenge

        return finish_verification(challenge.user, recovery_code: true) if challenge.user.consume_recovery_code(params[:code])

        case challenge.verify(params[:code])
        when :verified
          finish_verification(challenge.user)
        when :invalid then render_api_error("INVALID_OTP", status: :unauthorized)
        when :locked then render_api_error("OTP_LOCKED", status: :too_many_requests)
        else render_invalid_challenge
        end
      end

      def resend_otp
        challenge = find_challenge
        return render_invalid_challenge unless challenge&.usable?
        return render_api_error("OTP_RESEND_TOO_SOON", status: :too_many_requests) unless challenge.resend_available?

        new_challenge, code = LoginChallenge.issue_for!(challenge.user)
        LoginOtpMailer.with(user: challenge.user, code: code).verification_code.deliver_later
        render json: challenge_json(new_challenge), status: :accepted
      end

      def destroy
        AuditLog.record!(action: "session.logout", actor: Current.user, auditable: Current.user, request: request)
        terminate_session
        head :no_content
      end

      private
        def user_json(user)
          user.as_json(only: %i[id email_address role]).merge(permissions: user.permission_keys, avatar_url: user.avatar.attached? ? rails_blob_path(user.avatar, only_path: true) : nil)
        end

        def render_inactive_account
          render_api_error("ACCOUNT_INACTIVE", status: :forbidden, email: ENV.fetch("SUPPORT_EMAIL", "example@mail.com"))
        end

        def otp_trusted_for?(user)
          User.find_signed(cookies[:otp_trust], purpose: :otp_trust) == user && user.email_verified?
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          false
        end

        def remember_otp_verification_for(user)
          cookies[:otp_trust] = { value: user.signed_id(purpose: :otp_trust, expires_in: 1.hour), expires: 1.hour.from_now, httponly: true, same_site: :lax, secure: Rails.env.production? }
        end

        def find_challenge
          LoginChallenge.find_signed(params[:challenge_token], purpose: :login_otp)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end

        def challenge_json(challenge)
          { otp_required: true, account_unverified: !challenge.user.email_verified?, challenge_token: challenge.token, email_hint: challenge.user.email_address.gsub(/(?<=.).(?=[^@]*?@)/, "*"), expires_in: LoginChallenge::LIFETIME.to_i, resend_in: LoginChallenge::RESEND_DELAY.to_i }
        end

        def render_invalid_challenge
          render_api_error("INVALID_OTP_CHALLENGE", status: :unauthorized)
        end

        def finish_verification(user, recovery_code: false)
          return render_inactive_account unless user.active?

          user.update!(email_verified_at: Time.current) unless user.email_verified?
          remember_otp_verification_for(user)
          start_new_session_for(user)
          action = recovery_code ? "session.recovery_code_login" : "session.login"
          AuditLog.record!(action: action, actor: user, auditable: user, request: request)
          render json: { user: user_json(user) }, status: :created
        end
    end
  end
end
