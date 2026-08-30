module Api
  module V1
    class StepUpsController < ApplicationController
      PURPOSES = %w[account_security password_change email_change recovery_codes passkey_delete sessions_revoke admin_user_update admin_role_change admin_approval totp_disable].freeze

      rate_limit to: 10, within: 5.minutes, by: -> { Current.user.id },
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def create
        purpose = params[:purpose].to_s
        return render_api_error("INVALID_STEP_UP_PURPOSE", status: :unprocessable_content) unless purpose.in?(PURPOSES)
        return render_api_error("CURRENT_PASSWORD_INVALID", status: :unauthorized, details: { current_password: [ I18n.t("api.errors.current_password_invalid") ] }) unless Current.user.authenticate(params[:current_password])

        challenge = issue_step_up_challenge!(purpose)
        render json: { challenge_token: challenge.token, email_hint: mask_email(Current.user.email_address), expires_in: StepUpChallenge::LIFETIME.to_i }, status: :accepted
      end

      def verify
        purpose = params[:purpose].to_s
        result = verify_step_up_challenge(params[:challenge_token], params[:code], purpose)
        case result
        when String
          AuditLog.record!(action: "account.step_up_verified", actor: Current.user, auditable: Current.user, metadata: { purpose: purpose }, request: request)
          render json: { step_up_token: result, expires_in: StepUpChallenge::GRANT_LIFETIME.to_i }
        when :invalid then render_api_error("INVALID_OTP", status: :unauthorized, details: { code: [ I18n.t("api.errors.invalid_otp") ] })
        when :locked then render_api_error("OTP_LOCKED", status: :too_many_requests, details: { code: [ I18n.t("api.errors.otp_locked") ] })
        else render_api_error("INVALID_STEP_UP_CHALLENGE", status: :unauthorized)
        end
      end

      private
        def mask_email(email)
          email.gsub(/(?<=.).(?=[^@]*?@)/, "*")
        end
    end
  end
end
