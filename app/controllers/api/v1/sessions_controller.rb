module Api
  module V1
    class SessionsController < ApplicationController
      class_attribute :captcha_verifier, default: CaptchaVerifier
      allow_unauthenticated_access only: %i[create verify_otp resend_otp passkey_options passkey]
      rate_limit to: 10, within: 3.minutes, only: %i[create verify_otp resend_otp passkey_options passkey],
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def show
        render json: { user: user_json(Current.user) }
      end

      def create
        protection = LoginProtection.new(email_address: params[:email_address], ip_address: request.remote_ip, user_agent: request.user_agent, captcha_enabled: captcha_verifier.enabled?)
        candidate = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
        captcha_verified = verify_captcha_if_required(protection, candidate)
        return if performed?
        return blocked_login(candidate, protection) if protection.hard_locked?(candidate, captcha_verified: captcha_verified)

        protection.delay!

        user = User.authenticate_by(params.permit(:email_address, :password))
        if user && !user.active?
          render_inactive_account
        elsif user
          protection.record_success!(user)
          if otp_trusted_for?(user)
            start_new_session_for(user)
            AuditLog.record!(action: "session.login", actor: user, auditable: user, request: request)
            return render json: { otp_required: false, user: user_json(user) }, status: :created
          end
          challenge, code = LoginChallenge.issue_for!(user)
          LoginOtpMailer.with(user: user, code: code).verification_code.deliver_later
          render json: challenge_json(challenge), status: :accepted
        else
          result = protection.record_failure!(candidate, captcha_verified: captcha_verified)
          AuditLog.record!(action: "session.login_failed", actor: candidate, auditable: candidate, metadata: { email_digest: protection.email_digest }, request: request)
          notify_suspicious_login(candidate, protection, result) if result[:locked] || protection.ip_attack?
          render_api_error("INVALID_CREDENTIALS", status: :unauthorized, details: { password: [ I18n.t("api.errors.invalid_credentials") ] })
        end
      end

      def verify_otp
        challenge = find_challenge
        return render_invalid_challenge unless challenge

        return finish_verification(challenge.user) if challenge.user.verify_totp(params[:code])
        return finish_verification(challenge.user, recovery_code: true) if challenge.user.consume_recovery_code(params[:code])

        case challenge.verify(params[:code])
        when :verified
          finish_verification(challenge.user)
        when :invalid then render_api_error("INVALID_OTP", status: :unauthorized, details: { code: [ I18n.t("api.errors.invalid_otp") ] })
        when :locked then render_api_error("OTP_LOCKED", status: :too_many_requests, details: { code: [ I18n.t("api.errors.otp_locked") ] })
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

      def passkey_options
        return passkeys_disabled unless WebauthnConfiguration.enabled?
        user = User.find_by(email_address: params[:email_address].to_s.strip.downcase, active: true)
        return render_api_error("INVALID_CREDENTIALS", status: :unauthorized, details: { email_address: [ I18n.t("api.errors.invalid_credentials") ] }) unless user&.webauthn_credentials&.exists?

        options = WebAuthn::Credential.options_for_get(allow: user.webauthn_credentials.pluck(:external_id), user_verification: "required")
        render json: { options: options, challenge_token: passkey_token(user, options.challenge) }
      end

      def passkey
        return passkeys_disabled unless WebauthnConfiguration.enabled?
        payload = Rails.application.message_verifier(:webauthn_ceremony).verify(params[:challenge_token])
        return invalid_passkey unless payload["ceremony"] == "authentication"

        user = User.find(payload.fetch("user_id"))
        return render_inactive_account unless user.active?
        assertion = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)
        stored = user.webauthn_credentials.find_by!(external_id: assertion.id)
        assertion.verify(payload.fetch("challenge"), public_key: stored.public_key, sign_count: stored.sign_count)
        stored.update!(sign_count: assertion.sign_count, last_used_at: Time.current)
        LoginProtection.new(email_address: user.email_address, ip_address: request.remote_ip, user_agent: request.user_agent).record_success!(user)
        start_new_session_for(user)
        AuditLog.record!(action: "account.passkey_login", actor: user, auditable: user, request: request)
        render json: { user: user_json(user) }, status: :created
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound, WebAuthn::Error, ActionController::ParameterMissing
        invalid_passkey
      end

      def destroy
        AuditLog.record!(action: "session.logout", actor: Current.user, auditable: Current.user, request: request)
        terminate_session
        head :no_content
      end

      private
        def user_json(user)
          user.as_json(only: %i[id email_address role first_name last_name]).merge(permissions: user.permission_keys, avatar_url: user.avatar.attached? ? rails_blob_path(user.avatar, only_path: true) : nil)
        end

        def passkey_token(user, challenge)
          Rails.application.message_verifier(:webauthn_ceremony).generate({ ceremony: "authentication", user_id: user.id, challenge: challenge }, expires_in: 5.minutes)
        end

        def passkeys_disabled
          render_api_error("WEBAUTHN_DISABLED", status: :unprocessable_content)
        end

        def invalid_passkey
          render_api_error("PASSKEY_INVALID", status: :unauthorized)
        end

        def render_inactive_account
          render_api_error("ACCOUNT_INACTIVE", status: :forbidden, email: ENV.fetch("SUPPORT_EMAIL", "example@mail.com"))
        end

        def otp_trusted_for?(user)
          return false if mfa_required_for?(user)

          payload = Rails.application.message_verifier(:otp_trust).verify(cookies[:otp_trust])
          payload["user_id"] == user.id && payload["authentication_version"] == user.authentication_version && user.email_verified?
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          false
        end

        def remember_otp_verification_for(user)
          return if mfa_required_for?(user)

          token = Rails.application.message_verifier(:otp_trust).generate({ user_id: user.id, authentication_version: user.authentication_version }, expires_in: 1.hour)
          cookies[:otp_trust] = { value: token, expires: 1.hour.from_now, httponly: true, same_site: :lax, secure: Rails.env.production? }
        end

        def find_challenge
          LoginChallenge.find_signed(params[:challenge_token], purpose: :login_otp)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end

        def mfa_required_for?(user)
          roles = ENV.fetch("MFA_REQUIRED_ROLES", ENV.fetch("ADMIN_MFA_REQUIRED", "true") == "true" ? "admin" : "").split(",").map(&:strip)
          roles.include?(user.role)
        end

        def challenge_json(challenge)
          { otp_required: true, account_unverified: !challenge.user.email_verified?, totp_available: challenge.user.totp_enabled?, challenge_token: challenge.token, email_hint: challenge.user.email_address.gsub(/(?<=.).(?=[^@]*?@)/, "*"), expires_in: LoginChallenge::LIFETIME.to_i, resend_in: LoginChallenge::RESEND_DELAY.to_i }
        end

        def render_invalid_challenge
          render_api_error("INVALID_OTP_CHALLENGE", status: :unauthorized)
        end

        def blocked_login(user, protection)
          notify_suspicious_login(user, protection, { locked: true, risk_score: protection.risk_score(user) })
          AuditLog.record!(action: "session.login_blocked", actor: user, auditable: user, metadata: { email_digest: protection.email_digest }, request: request)
          render_api_error("LOGIN_TEMPORARILY_BLOCKED", status: :too_many_requests)
        end

        def verify_captcha_if_required(protection, user)
          return false unless protection.captcha_required?(user)

          verified = captcha_verifier.verify(token: params[:captcha_token], remote_ip: request.remote_ip)
          return true if verified

          render_api_error("CAPTCHA_REQUIRED", status: :unprocessable_content, details: { captcha_required: true, captcha_site_key: captcha_verifier.site_key })
          false
        end

        def notify_suspicious_login(user, protection, result)
          return unless protection.alert_due?(user)

          user.update_column(:security_alerted_at, Time.current)
          SecurityNotificationMailer.with(user: user, ip_address: request.remote_ip, user_agent: request.user_agent, risk_score: result[:risk_score]).suspicious_login.deliver_later
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
