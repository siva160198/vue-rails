module Api
  module V1
    module Admin
      class RolesController < ApplicationController
        rate_limit to: 40, within: 1.minute, only: %i[create update destroy],
          by: -> { Current.user&.id || request.remote_ip },
          with: -> { render json: { error: "Terlalu banyak perubahan role. Coba lagi sebentar." }, status: :too_many_requests }

        PERMISSION_DEPENDENCIES = {
          "users.update" => "users.view",
          "roles.manage" => "roles.view"
        }.freeze

        def index
          authorize Role
          roles = policy_scope(Role)
          roles = roles.where("name ILIKE :search OR key ILIKE :search OR description ILIKE :search", search: "%#{Role.sanitize_sql_like(params[:search])}%") if params[:search].present?
          total = roles.count
          per_page = params.fetch(:per_page, 10).to_i.clamp(5, 50)
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          sort = %w[name key description created_at].include?(params[:sort]) ? params[:sort] : "name"
          roles = roles.order(sort => (params[:direction] == "desc" ? :desc : :asc)).offset((page - 1) * per_page).limit(per_page)
          render json: { roles: roles.map { |role| role_json(role) }, permissions: permissions_json, pagination: { total: total } }
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
          role.assign_attributes(role_params.except(:key, :permission_keys))
          desired_permission_ids = permissions_for(role).ids.sort
          unchanged = !role.changed? && role.permission_ids.sort == desired_permission_ids
          return render json: { role: role_json(role), unchanged: true } if unchanged

          Role.transaction do
            role.save!
            role.permission_ids = desired_permission_ids
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
            role.permissions = permissions_for(role)
          end

          def permissions_for(role)
            keys = role.key == "admin" ? Permission.pluck(:key) : Array(role_params[:permission_keys])
            keys += keys.filter_map { |key| PERMISSION_DEPENDENCIES[key] }
            Permission.where(key: keys.uniq)
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
