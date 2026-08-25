module Api
  module V1
    module Admin
      class AuditLogsController < ApplicationController
        def index
          authorize AuditLog
          logs = policy_scope(AuditLog).includes(:actor).order(created_at: :desc).limit(100)

          render json: {
            audit_logs: logs.map do |log|
              log.as_json(only: %i[id action auditable_type auditable_id metadata ip_address created_at]).merge(
                actor_email: log.actor&.email_address
              )
            end
          }
        end
      end
    end
  end
end
