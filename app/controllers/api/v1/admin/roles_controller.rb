module Api
  module V1
    module Admin
      class RolesController < ApplicationController
        PERMISSION_DEPENDENCIES = {
          "users.update" => "users.view",
          "roles.manage" => "roles.view"
        }.freeze

        def index
          authorize Role
          roles = policy_scope(Role).order(system: :desc, name: :asc)
          render json: { roles: roles.map { |role| role_json(role) }, permissions: permissions_json }
        end

        def create
          role = Role.new(role_params.except(:permission_keys))
          authorize role
          Role.transaction do
            role.save!
            assign_permissions(role)
          end
          record_audit("admin.role_created", role, after: role_snapshot(role))
          render json: { role: role_json(role) }, status: :created
        rescue ActiveRecord::RecordInvalid
          render json: { error: role.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        def update
          role = Role.find(params[:id])
          authorize role
          before = role_snapshot(role)
          Role.transaction do
            role.update!(role_params.except(:key, :permission_keys))
            assign_permissions(role)
          end
          record_audit("admin.role_updated", role, before: before, after: role_snapshot(role))
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
            params.permit(:key, :name, :description, permission_keys: [])
          end

          def role_json(role)
            role.as_json(only: %i[id key name description system created_at]).merge(
              users_count: role.users.size,
              permission_keys: role.permissions.order(:key).pluck(:key)
            )
          end

          def permissions_json
            Permission.order(:key).map { |permission| permission.as_json(only: %i[key name description]) }
          end

          def assign_permissions(role)
            keys = role.key == "admin" ? Permission.pluck(:key) : Array(role_params[:permission_keys])
            keys += keys.filter_map { |key| PERMISSION_DEPENDENCIES[key] }
            role.permissions = Permission.where(key: keys)
          end

          def role_snapshot(role)
            role.slice("name", "description").merge("permission_keys" => role.permission_keys)
          end

          def record_audit(action, role, metadata = {})
            AuditLog.record!(action: action, actor: Current.user, auditable: role, metadata: metadata, request: request)
          end
      end
    end
  end
end
