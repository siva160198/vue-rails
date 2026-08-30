module Api
  module V1
    class StatusController < ActionController::API
      def show
        render json: { status: "ok" }
      end
    end
  end
end
