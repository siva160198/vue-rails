module Api
  module V1
    module Admin
      class RolesController < ApplicationController
        def index
          authorize Role
          roles = policy_scope(Role).order(system: :desc, name: :asc)
          render json: { roles: roles.map { |role| role_json(role) } }
        end

        def create
          role = Role.new(role_params)
          authorize role
          role.save!
          record_audit("admin.role_created", role)
          render json: { role: role_json(role) }, status: :created
        rescue ActiveRecord::RecordInvalid
          render json: { error: role.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        def update
          role = Role.find(params[:id])
          authorize role
          before = role.slice("name", "description")
          role.update!(role_params.except(:key))
          record_audit("admin.role_updated", role, before: before)
          render json: { role: role_json(role) }
        rescue ActiveRecord::RecordInvalid
          render json: { error: role.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        def destroy
          role = Role.find(params[:id])
          authorize role
          snapshot = role_json(role)
          role.destroy!
          AuditLog.record!(action: "admin.role_deleted", actor: Current.user, metadata: { role: snapshot }, request: request)
          head :no_content
        end

        private
          def role_params
            params.permit(:key, :name, :description)
          end

          def role_json(role)
            role.as_json(only: %i[id key name description system created_at]).merge(users_count: role.users.size)
          end

          def record_audit(action, role, metadata = {})
            AuditLog.record!(action: action, actor: Current.user, auditable: role, metadata: metadata, request: request)
          end
      end
    end
  end
end
