module Api
  module V1
    module Admin
      class DashboardController < ApplicationController
        def show
          authorize :dashboard, :show?
          range = Reporting::DateRange.new(start_date: params[:start_date], end_date: params[:end_date])
          report = Rails.cache.fetch("dashboard-report:v1:#{range.start_date}:#{range.end_date}", expires_in: 30.seconds) do
            Reporting::DailyCount.new(scope: User.all, range: range).call
          end

          render json: {
            user: Current.user.as_json(only: %i[id email_address role first_name last_name]).merge(permissions: Current.user.permission_keys),
            report: report,
            metrics: {
              users: Rails.cache.fetch("dashboard-users:v1", expires_in: 30.seconds) { User.count },
              active_sessions: Rails.cache.fetch("dashboard-sessions:v1", expires_in: 30.seconds) { Session.active.count }
            }
          }
        rescue Reporting::DateRange::Invalid
          render_api_error("INVALID_REPORT_RANGE", status: :unprocessable_content, details: { start_date: [ I18n.t("api.errors.invalid_report_range") ], end_date: [ I18n.t("api.errors.invalid_report_range") ] })
        end
      end
    end
  end
end
