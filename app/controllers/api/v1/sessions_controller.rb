module Api
  module V1
    class SessionsController < ApplicationController
      allow_unauthenticated_access only: %i[create verify_otp resend_otp]
      rate_limit to: 10, within: 3.minutes, only: %i[create verify_otp resend_otp],
        with: -> { render json: { error: "Terlalu banyak percobaan. Coba lagi nanti." }, status: :too_many_requests }

      def show
        render json: { user: user_json(Current.user) }
      end

      def create
        user = User.authenticate_by(params.permit(:email_address, :password))

        if user
          challenge, code = LoginChallenge.issue_for!(user)
          LoginOtpMailer.with(user: user, code: code).verification_code.deliver_now
          render json: challenge_json(challenge), status: :accepted
        else
          render json: { error: "Email atau password tidak valid." }, status: :unauthorized
        end
      end

      def verify_otp
        challenge = find_challenge
        return render_invalid_challenge unless challenge

        case challenge.verify(params[:code])
        when :verified
          challenge.user.update!(email_verified_at: Time.current) unless challenge.user.email_verified?
          start_new_session_for(challenge.user)
          render json: { user: user_json(challenge.user) }, status: :created
        when :invalid
          render json: { error: "Kode OTP tidak valid." }, status: :unauthorized
        when :locked
          render json: { error: "Terlalu banyak percobaan. Silakan login kembali." }, status: :too_many_requests
        else
          render_invalid_challenge
        end
      end

      def resend_otp
        challenge = find_challenge
        return render_invalid_challenge unless challenge

        return render_invalid_challenge unless challenge.usable?

        unless challenge.resend_available?
          return render json: { error: "Tunggu 60 detik sebelum mengirim ulang OTP." }, status: :too_many_requests
        end

        new_challenge, code = LoginChallenge.issue_for!(challenge.user)
        LoginOtpMailer.with(user: challenge.user, code: code).verification_code.deliver_now
        render json: challenge_json(new_challenge), status: :accepted
      end

      def destroy
        terminate_session
        head :no_content
      end

      private
        def user_json(user)
          user.as_json(only: %i[id email_address role])
        end

        def find_challenge
          LoginChallenge.find_signed(params[:challenge_token], purpose: :login_otp)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
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

        def render_invalid_challenge
          render json: { error: "Sesi OTP tidak valid atau sudah kedaluwarsa. Silakan login kembali." }, status: :unauthorized
        end
    end
  end
end
