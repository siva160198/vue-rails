module Api
  module V1
    class RegistrationsController < ApplicationController
      allow_unauthenticated_access only: :create
      rate_limit to: 5, within: 10.minutes, only: :create,
        with: -> { render json: { error: "Terlalu banyak pendaftaran. Coba lagi nanti." }, status: :too_many_requests }

      def create
        user = User.new(registration_params)
        user.role = :member

        User.transaction do
          user.save!
          challenge, code = LoginChallenge.issue_for!(user)
          LoginOtpMailer.with(user: user, code: code).verification_code.deliver_now
          AuditLog.record!(action: "user.registered", actor: user, auditable: user, request: request)

          render json: challenge_json(challenge), status: :created
        end
      rescue ActiveRecord::RecordInvalid
        render json: { error: user.errors.full_messages.to_sentence, errors: user.errors.to_hash },
          status: :unprocessable_content
      rescue ActiveRecord::RecordNotUnique
        render json: { error: "Email sudah terdaftar." }, status: :unprocessable_content
      end

      private
        def registration_params
          params.permit(:email_address, :password, :password_confirmation)
        end

        def challenge_json(challenge)
          {
            otp_required: true,
            challenge_token: challenge.token,
            email_hint: challenge.user.email_address.gsub(/(?<=.).(?=[^@]*?@)/, "*"),
            expires_in: LoginChallenge::LIFETIME.to_i,
            resend_in: LoginChallenge::RESEND_DELAY.to_i
          }
        end
    end
  end
end
