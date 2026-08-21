module Api
  module V1
    class StatusController < ActionController::API
      def show
        connection = ActiveRecord::Base.connection

        render json: {
          status: "ok",
          application: "tourplan",
          database: {
            adapter: connection.adapter_name,
            name: connection.current_database
          }
        }
      end
    end
  end
end
