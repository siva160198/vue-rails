module Api
  module V1
    class PasskeysController < ApplicationController
      rate_limit to: 10, within: 5.minutes, by: -> { Current.user&.id || request.remote_ip },
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def options
        authorize :account_security, :update?
        return passkeys_disabled unless WebauthnConfiguration.enabled?
        return render_api_error("CURRENT_PASSWORD_INVALID", status: :unauthorized, details: { current_password: [ I18n.t("api.errors.current_password_invalid") ] }) unless Current.user.authenticate(params[:current_password])

        Current.user.update!(webauthn_user_handle: WebAuthn.generate_user_id) if Current.user.webauthn_user_handle.blank?
        options = WebAuthn::Credential.options_for_create(
          user: { id: Current.user.webauthn_user_handle, name: Current.user.email_address, display_name: Current.user.email_address },
          exclude: Current.user.webauthn_credentials.pluck(:external_id),
          authenticator_selection: { resident_key: "preferred", user_verification: "required" }
        )
        render json: { options: options, challenge_token: ceremony_token("registration", Current.user.id, options.challenge) }
      end

      def create
        authorize :account_security, :update?
        return passkeys_disabled unless WebauthnConfiguration.enabled?
        payload = verify_ceremony_token(params[:challenge_token], "registration")
        return invalid_passkey unless payload && payload["user_id"] == Current.user.id

        credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)
        credential.verify(payload.fetch("challenge"))
        stored = Current.user.webauthn_credentials.create!(
          external_id: credential.id,
          public_key: credential.public_key,
          sign_count: credential.sign_count,
          nickname: params[:nickname].presence || I18n.t("api.passkeys.default_nickname"),
          transports: Array(params.dig(:credential, :response, :transports)).map(&:to_s).intersection(%w[usb nfc ble internal hybrid]),
          authenticator_attachment: params.dig(:credential, :authenticatorAttachment).to_s.presence
        )
        AuditLog.record!(action: "account.passkey_added", actor: Current.user, auditable: Current.user, request: request)
        SecurityNotificationMailer.with(user: Current.user, security_event: "passkey_added").security_setting_changed.deliver_later
        render json: { passkey: stored.as_json(only: %i[id nickname transports authenticator_attachment last_used_at created_at]) }, status: :created
      rescue WebAuthn::Error, ActiveRecord::RecordInvalid, ActionController::ParameterMissing
        invalid_passkey
      end

      def destroy
        authorize :account_security, :update?
        credential = Current.user.webauthn_credentials.find(params[:id])
        return unless require_step_up!("passkey_delete")
        required_roles = ENV.fetch("MFA_REQUIRED_ROLES", "admin").split(",").map(&:strip)
        if required_roles.include?(Current.user.role) && Current.user.webauthn_credentials.count == 1 && !Current.user.totp_enabled?
          return render_api_error("LAST_AUTHENTICATION_METHOD_REQUIRED", status: :unprocessable_content)
        end
        credential.destroy!
        AuditLog.record!(action: "account.passkey_removed", actor: Current.user, auditable: Current.user, request: request)
        SecurityNotificationMailer.with(user: Current.user, security_event: "passkey_removed").security_setting_changed.deliver_later
        head :no_content
      end

      private
        def ceremony_token(ceremony, user_id, challenge)
          Rails.application.message_verifier(:webauthn_ceremony).generate({ ceremony: ceremony, user_id: user_id, challenge: challenge }, expires_in: 5.minutes)
        end

        def verify_ceremony_token(token, ceremony)
          payload = Rails.application.message_verifier(:webauthn_ceremony).verify(token)
          payload if payload["ceremony"] == ceremony
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end

        def passkeys_disabled
          render_api_error("WEBAUTHN_DISABLED", status: :unprocessable_content)
        end

        def invalid_passkey
          render_api_error("PASSKEY_INVALID", status: :unprocessable_content)
        end
    end
  end
end
