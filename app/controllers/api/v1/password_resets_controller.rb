module Api
  module V1
    class PasswordResetsController < ApplicationController
      allow_unauthenticated_access only: %i[show create update]
      rate_limit to: 5, within: 10.minutes, only: :create,
        with: -> { render json: generic_response, status: :accepted }
      rate_limit to: 10, within: 10.minutes, only: :update,
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def create
        user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
        PasswordsMailer.reset(user).deliver_later if user

        render json: generic_response, status: :accepted
      end

      def show
        if find_user
          render json: { valid: true }
        else
          render_invalid_token
        end
      end

      def update
        user = find_user
        return render_invalid_token unless user

        user.assign_attributes(password_params)
        if user.save
          user.sessions.destroy_all
          user.increment!(:authentication_version)
          user.login_challenges.delete_all
          user.step_up_challenges.delete_all
          AuditLog.record!(action: "password.reset", actor: user, auditable: user, request: request)
          SecurityNotificationMailer.with(user: user).password_changed.deliver_later
          render json: { message: "Password berhasil diperbarui. Silakan login." }
        else
          render_validation_error(user)
        end
      end

      private
        def password_params
          params.permit(:password, :password_confirmation)
        end

        def find_user
          User.find_by_password_reset_token(params[:token])
        end

        def generic_response
          { message: "Jika email terdaftar, link reset telah dikirim." }
        end

        def render_invalid_token
          render_api_error("INVALID_PASSWORD_RESET_TOKEN", status: :unauthorized)
        end
    end
  end
end
