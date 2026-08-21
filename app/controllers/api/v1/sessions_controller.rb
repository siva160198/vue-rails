module Api
  module V1
    class SessionsController < ApplicationController
      allow_unauthenticated_access only: :create
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render json: { error: "Terlalu banyak percobaan. Coba lagi nanti." }, status: :too_many_requests }

      def show
        render json: { user: user_json(Current.user) }
      end

      def create
        user = User.authenticate_by(params.permit(:email_address, :password))

        if user
          start_new_session_for(user)
          render json: { user: user_json(user) }, status: :created
        else
          render json: { error: "Email atau password tidak valid." }, status: :unauthorized
        end
      end

      def destroy
        terminate_session
        head :no_content
      end

      private
        def user_json(user)
          user.as_json(only: %i[id email_address role])
        end
    end
  end
end
