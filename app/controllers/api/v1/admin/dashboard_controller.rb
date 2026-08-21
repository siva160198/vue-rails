module Api
  module V1
    module Admin
      class DashboardController < ApplicationController
        def show
          authorize :dashboard, :show?

          render json: {
            user: Current.user.as_json(only: %i[id email_address role]),
            metrics: {
              users: User.count,
              active_sessions: Session.count
            }
          }
        end
      end
    end
  end
end
