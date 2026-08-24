module Api
  module V1
    class PasswordResetsController < ApplicationController
      allow_unauthenticated_access only: %i[create update]
      rate_limit to: 5, within: 10.minutes, only: :create,
        with: -> { render json: generic_response, status: :accepted }
      rate_limit to: 10, within: 10.minutes, only: :update,
        with: -> { render json: { error: "Terlalu banyak percobaan. Coba lagi nanti." }, status: :too_many_requests }

      def create
        user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
        token = user ? issue_challenge(user) : dummy_token

        render json: generic_response.merge(challenge_token: token), status: :accepted
      end

      def update
        challenge = find_challenge
        return render_invalid_challenge unless challenge

        status, errors = challenge.reset_password(
          code: params[:code],
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        case status
        when :reset
          render json: { message: "Password berhasil diperbarui. Silakan login." }
        when :invalid
          render json: { error: "Kode OTP tidak valid." }, status: :unauthorized
        when :locked
          render json: { error: "Terlalu banyak percobaan. Minta kode reset baru." }, status: :too_many_requests
        when :invalid_password
          render json: { error: errors.full_messages.to_sentence, errors: errors.to_hash }, status: :unprocessable_content
        else
          render_invalid_challenge
        end
      end

      private
        def issue_challenge(user)
          challenge, code = PasswordResetChallenge.issue_for!(user)
          PasswordsMailer.reset(user, code).deliver_now
          challenge.token
        end

        def dummy_token
          Rails.application.message_verifier(:password_reset_dummy).generate(
            SecureRandom.hex(16), expires_in: PasswordResetChallenge::LIFETIME
          )
        end

        def find_challenge
          PasswordResetChallenge.find_signed(params[:challenge_token], purpose: :password_reset_otp)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end

        def generic_response
          { message: "Jika email terdaftar, kode reset telah dikirim." }
        end

        def render_invalid_challenge
          render json: { error: "Sesi reset tidak valid atau sudah kedaluwarsa. Minta kode baru." }, status: :unauthorized
        end
    end
  end
end
