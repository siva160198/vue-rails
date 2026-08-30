module Api
  module V1
    class AccountSecurityController < ApplicationController
      SECURITY_ACTIONS = %w[
        session.login session.login_failed session.recovery_code_login session.logout
        session.revoked session.others_revoked account.password_changed account.email_changed
        account.recovery_codes_regenerated account.passkey_added account.passkey_removed
        account.passkey_login session.login_blocked session.expired session.rotated
        account.step_up_verified account.totp_enabled account.totp_disabled
      ].freeze

      rate_limit to: 10, within: 5.minutes, only: %i[password request_email verify_email request_recovery_codes verify_recovery_codes request_totp verify_totp disable_totp],
        by: -> { Current.user&.id || request.remote_ip },
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def show
        authorize :account_security
        email_digests = [ EmailPrivacyDigest.call(Current.user.email_address), EmailPrivacyDigest.legacy(Current.user.email_address) ]
        scope = AuditLog.where(action: SECURITY_ACTIONS).where(
          "actor_id = :user_id OR (action = 'session.login_failed' AND metadata ->> 'email_digest' IN (:digests))",
          user_id: Current.user.id,
          digests: email_digests
        )
        events, pagination = paginate_cursor_api(scope, search_columns: %w[action ip_address user_agent], sortable_columns: %w[action ip_address user_agent created_at], default_sort: :created_at, default_direction: :desc)
        render json: {
          events: events.map { |event| event.as_json(only: %i[id action ip_address user_agent created_at]) },
          passkeys: Current.user.webauthn_credentials.order(created_at: :desc).map { |credential| passkey_json(credential) },
          passkeys_enabled: WebauthnConfiguration.enabled?,
          recovery_code_count: Current.user.recovery_code_digests.size,
          totp_enabled: Current.user.totp_enabled?,
          pagination: pagination
        }
      end

      def password
        authorize :account_security, :update?
        return invalid_current_password if params.key?(:current_password) && !Current.user.authenticate(params[:current_password])
        return unless require_step_up!("password_change")
        return render_api_error("PASSWORD_UNCHANGED", status: :unprocessable_content, details: { password: [ I18n.t("api.errors.password_unchanged") ] }) if Current.user.authenticate(params[:password])

        Current.user.assign_attributes(password: params[:password], password_confirmation: params[:password_confirmation])
        return render_validation_error(Current.user) unless Current.user.save

        Current.user.sessions.where.not(id: Current.session.id).delete_all
        invalidate_authentication_trust!
        rotate_current_session!
        AuditLog.record!(action: "account.password_changed", actor: Current.user, auditable: Current.user, request: request)
        SecurityNotificationMailer.with(user: Current.user).password_changed.deliver_later
        render json: { user: user_json(Current.user) }
      end

      def request_email
        authorize :account_security, :update?
        return invalid_current_password unless Current.user.authenticate(params[:current_password])

        email = params[:email_address].to_s.strip.downcase
        return render_api_error("EMAIL_UNCHANGED", status: :unprocessable_content, details: { email_address: [ I18n.t("api.errors.email_unchanged") ] }) if email == Current.user.email_address
        return render_api_error("EMAIL_ALREADY_REGISTERED", status: :unprocessable_content, details: { email_address: [ I18n.t("api.errors.email_already_registered") ] }) if User.exists?(email_address: email)

        probe = Current.user.dup
        probe.email_address = email
        return render_validation_error(probe) unless probe.valid?

        challenge, code = EmailChangeChallenge.issue_for!(Current.user, email)
        EmailChangeMailer.with(email_address: email, code: code).verification_code.deliver_later
        render json: { challenge_token: challenge.token, email_hint: mask_email(email), expires_in: EmailChangeChallenge::LIFETIME.to_i }, status: :accepted
      end

      def verify_email
        authorize :account_security, :update?
        challenge = EmailChangeChallenge.find_signed(params[:challenge_token], purpose: :email_change)
        return invalid_email_challenge unless challenge&.user == Current.user

        case challenge.verify(params[:code])
        when :verified
          return render_api_error("EMAIL_ALREADY_REGISTERED", status: :unprocessable_content) if User.where.not(id: Current.user.id).exists?(email_address: challenge.email_address)

          previous_email = Current.user.email_address
          Current.user.update!(email_address: challenge.email_address, email_verified_at: Time.current)
          raw_revert_token = SecureRandom.urlsafe_base64(32)
          Current.user.update_columns(
            pending_email_revert_address: SecurityEncryptor.encrypt(previous_email, purpose: "email-revert"),
            pending_email_revert_digest: Digest::SHA256.hexdigest(raw_revert_token),
            pending_email_revert_expires_at: 24.hours.from_now
          )
          Current.user.sessions.where.not(id: Current.session.id).delete_all
          invalidate_authentication_trust!
          rotate_current_session!
          AuditLog.record!(action: "account.email_changed", actor: Current.user, auditable: Current.user, request: request)
          SecurityNotificationMailer.with(user: Current.user, previous_email: previous_email, revert_token: email_revert_token(Current.user, raw_revert_token)).email_changed.deliver_later
          render json: { user: user_json(Current.user) }
        when :invalid then render_api_error("INVALID_OTP", status: :unauthorized, details: { code: [ I18n.t("api.errors.invalid_otp") ] })
        when :locked then render_api_error("OTP_LOCKED", status: :too_many_requests, details: { code: [ I18n.t("api.errors.otp_locked") ] })
        else invalid_email_challenge
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        invalid_email_challenge
      end

      def request_recovery_codes
        authorize :account_security, :update?
        return invalid_current_password unless Current.user.authenticate(params[:current_password])

        challenge = issue_step_up_challenge!("recovery_codes")
        render json: { challenge_token: challenge.token, email_hint: mask_email(Current.user.email_address), expires_in: StepUpChallenge::LIFETIME.to_i }, status: :accepted
      end

      def request_totp
        authorize :account_security, :update?
        return unless require_step_up!("totp_enroll")

        secret = TotpAuthenticator.generate_secret
        Current.user.update!(pending_totp_secret: secret)
        render json: {
          secret: TotpAuthenticator.base32_secret(secret),
          provisioning_uri: TotpAuthenticator.provisioning_uri(secret: secret, email: Current.user.email_address, issuer: ENV.fetch("APP_NAME", "Vue Rails"))
        }
      end

      def verify_totp
        authorize :account_security, :update?
        return render_api_error("INVALID_SECURITY_CHALLENGE", status: :unauthorized) if Current.user.pending_totp_secret.blank?
        return render_api_error("INVALID_OTP", status: :unauthorized, details: { code: [ I18n.t("api.errors.invalid_otp") ] }) unless TotpAuthenticator.valid?(Current.user.pending_totp_secret, params[:code])

        Current.user.update!(totp_secret: Current.user.pending_totp_secret, pending_totp_secret: nil, totp_enabled_at: Time.current)
        AuditLog.record!(action: "account.totp_enabled", actor: Current.user, auditable: Current.user, request: request)
        SecurityNotificationMailer.with(user: Current.user, security_event: "totp_enabled").security_setting_changed.deliver_later
        render json: { totp_enabled: true }
      end

      def disable_totp
        authorize :account_security, :update?
        return unless require_step_up!("totp_disable")
        required_roles = ENV.fetch("MFA_REQUIRED_ROLES", "admin").split(",").map(&:strip)
        if required_roles.include?(Current.user.role) && !Current.user.webauthn_credentials.exists?
          return render_api_error("LAST_AUTHENTICATION_METHOD_REQUIRED", status: :unprocessable_content)
        end

        Current.user.update!(totp_secret: nil, totp_enabled_at: nil)
        AuditLog.record!(action: "account.totp_disabled", actor: Current.user, auditable: Current.user, request: request)
        SecurityNotificationMailer.with(user: Current.user, security_event: "totp_disabled").security_setting_changed.deliver_later
        render json: { totp_enabled: false }
      end

      def verify_recovery_codes
        authorize :account_security, :update?
        case verify_step_up_challenge(params[:challenge_token], params[:code], "recovery_codes")
        when String
          codes = Current.user.regenerate_recovery_codes!
          AuditLog.record!(action: "account.recovery_codes_regenerated", actor: Current.user, auditable: Current.user, request: request)
          render json: { recovery_codes: codes }
        when :invalid then render_api_error("INVALID_OTP", status: :unauthorized, details: { code: [ I18n.t("api.errors.invalid_otp") ] })
        when :locked then render_api_error("OTP_LOCKED", status: :too_many_requests, details: { code: [ I18n.t("api.errors.otp_locked") ] })
        else invalid_security_challenge
        end
      end

      private
        def invalid_current_password
          render_api_error("CURRENT_PASSWORD_INVALID", status: :unauthorized, details: { current_password: [ I18n.t("api.errors.current_password_invalid") ] })
        end

        def invalid_email_challenge
          render_api_error("INVALID_EMAIL_CHANGE_CHALLENGE", status: :unauthorized)
        end

        def invalid_security_challenge
          render_api_error("INVALID_SECURITY_CHALLENGE", status: :unauthorized)
        end

        def mask_email(email)
          email.gsub(/(?<=.).(?=[^@]*?@)/, "*")
        end

        def passkey_json(credential)
          credential.as_json(only: %i[id nickname transports authenticator_attachment last_used_at created_at])
        end

        def user_json(user)
          user.as_json(only: %i[id email_address role first_name last_name]).merge(permissions: user.permission_keys, avatar_url: user.avatar.attached? ? "/api/v1/profile/avatar?v=#{user.avatar.blob_id}" : nil)
        end

        def email_revert_token(user, raw_token)
          Rails.application.message_verifier(:email_revert).generate({ user_id: user.id, token: raw_token }, expires_in: 24.hours)
        end
    end
  end
end
