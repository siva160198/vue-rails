module Api
  module V1
    module Admin
      class AuditLogsController < ApplicationController
        def index
          authorize AuditLog
          logs = policy_scope(AuditLog).includes(:actor)
          logs = logs.where("action ILIKE ?", "%#{AuditLog.sanitize_sql_like(params[:search])}%") if params[:search].present?
          total = logs.count
          per_page = params.fetch(:per_page, 10).to_i.clamp(5, 50)
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          sort = %w[action auditable_type ip_address created_at].include?(params[:sort]) ? params[:sort] : "created_at"
          logs = logs.order(sort => (params[:direction] == "asc" ? :asc : :desc)).offset((page - 1) * per_page).limit(per_page)

          render json: {
            audit_logs: logs.map do |log|
              log.as_json(only: %i[id action auditable_type auditable_id metadata ip_address created_at]).merge(
                actor_email: log.actor&.email_address
              )
            end,
            pagination: { total: total }
          }
        end
      end
    end
  end
end
