module Api
  module V1
    class RegistrationsController < ApplicationController
      allow_unauthenticated_access only: :create
      rate_limit to: 5, within: 10.minutes, only: :create,
        with: -> { render_api_error("REGISTRATION_RATE_LIMITED", status: :too_many_requests) }
      rate_limit to: 3, within: 30.minutes, only: :create,
        by: -> { EmailPrivacyDigest.call(params[:email_address]) },
        with: -> { render_api_error("REGISTRATION_RATE_LIMITED", status: :too_many_requests) }, name: "registration-account"
      rate_limit to: 100, within: 10.minutes, only: :create, by: -> { "global" },
        with: -> { render_api_error("REGISTRATION_RATE_LIMITED", status: :too_many_requests) }, name: "registration-global"

      def create
        existing_user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
        return continue_unverified_registration(existing_user) if existing_user && !existing_user.email_verified? && existing_user.authenticate(params[:password])

        user = User.new(registration_params)
        user.role = "member"

        User.transaction do
          user.save!
          challenge, code = LoginChallenge.issue_for!(user)
          LoginOtpMailer.with(user: user, code: code).verification_code.deliver_later
          AuditLog.record!(action: "user.registered", actor: user, auditable: user, request: request)

          render json: challenge_json(challenge, account_unverified: false), status: :created
        end
      rescue ActiveRecord::RecordInvalid
        render_validation_error(user)
      rescue ActiveRecord::RecordNotUnique
        render_api_error("EMAIL_ALREADY_REGISTERED", status: :unprocessable_content, details: { email_address: [ I18n.t("api.errors.email_already_registered") ] })
      end

      private
        def continue_unverified_registration(user)
          challenge = user.login_challenges.active.order(created_at: :desc).first
          unless challenge&.usable? && challenge.created_at > LoginChallenge::RESEND_DELAY.ago
            challenge, code = LoginChallenge.issue_for!(user)
            LoginOtpMailer.with(user: user, code: code).verification_code.deliver_later
          end
          render json: challenge_json(challenge, account_unverified: true), status: :accepted
        end

        def registration_params
          params.permit(:email_address, :password, :password_confirmation)
        end

        def challenge_json(challenge, account_unverified:)
          {
            otp_required: true,
            account_unverified: account_unverified,
            challenge_token: challenge.token,
            email_hint: challenge.user.email_address.gsub(/(?<=.).(?=[^@]*?@)/, "*"),
            expires_in: LoginChallenge::LIFETIME.to_i,
            resend_in: LoginChallenge::RESEND_DELAY.to_i
          }
        end
    end
  end
end
