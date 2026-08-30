module Api
  module V1
    module Admin
      class AuditLogsController < ApplicationController
        def index
          authorize AuditLog
          logs, pagination = paginate_cursor_api(
            policy_scope(AuditLog).includes(:actor),
            search_columns: %w[action auditable_type ip_address],
            sortable_columns: %w[action auditable_type ip_address created_at],
            default_sort: :created_at,
            default_direction: :desc
          )

          render json: {
            audit_logs: logs.map do |log|
              log.as_json(only: %i[id action auditable_type auditable_id metadata ip_address created_at]).merge(
                actor_email: log.actor&.email_address
              )
            end,
            pagination: pagination
          }
        end
      end
    end
  end
end
