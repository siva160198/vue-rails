module Api
  module V1
    module Admin
      class RolesController < ApplicationController
        rate_limit to: 40, within: 1.minute, only: %i[create update destroy],
          by: -> { Current.user&.id || request.remote_ip },
          with: -> { render_api_error("ROLE_RATE_LIMITED", status: :too_many_requests) }

        PERMISSION_DEPENDENCIES = {
          "users.update" => "users.view",
          "account_security.update" => "account_security.view",
          "profile.update" => "profile.view",
          "roles.create" => "roles.view",
          "roles.update" => "roles.view",
          "roles.delete" => "roles.view",
          "security_approvals.update" => "security_approvals.view"
        }.freeze

        def index
          authorize Role
          roles, pagination = paginate_api(
            policy_scope(Role),
            search_columns: %w[name key description],
            sortable_columns: %w[name key description created_at],
            default_sort: :name
          )
          role_records = roles.includes(:permissions).to_a
          user_counts = User.where(role: role_records.map(&:key)).group(:role).count
          render json: { roles: role_records.map { |role| role_json(role, users_count: user_counts.fetch(role.key, 0)) }, permissions: permissions_json, pagination: pagination }
        end

        def create
          role = Role.new(role_params.except(:permission_keys))
          authorize role
          return render_validation_error(role) unless role.valid?
          return unless require_admin_dual_control!("admin.role_create", role_params.to_h)
          return unless require_step_up!("admin_role_change")
          Role.transaction do
            role.save!
            assign_permissions(role)
          end
          record_audit("admin.role_created", role, after: role_snapshot(role))
          render json: { role: role_json(role) }, status: :created
        rescue ActiveRecord::RecordInvalid
          render_validation_error(role)
        end

        def show
          role = Role.find(params[:id])
          authorize role
          render json: { role: role_json(role), permissions: permissions_json }
        end

        def update
          role = Role.find(params[:id])
          authorize role
          before = role_snapshot(role)
          role.assign_attributes(role_params.except(:key, :permission_keys))
          desired_permission_ids = permissions_for(role).ids.sort
          unchanged = !role.changed? && role.permission_ids.sort == desired_permission_ids
          return render json: { role: role_json(role), unchanged: true } if unchanged
          return unless require_admin_dual_control!("admin.role_update", role_params.to_h.merge("role_id" => role.id))
          return unless require_step_up!("admin_role_change")

          Role.transaction do
            role.save!
            role.permission_ids = desired_permission_ids
          end
          record_audit("admin.role_updated", role, before: before, after: role_snapshot(role))
          render json: { role: role_json(role) }
        rescue ActiveRecord::RecordInvalid
          render_validation_error(role)
        end

        def destroy
          role = Role.find(params[:id])
          authorize role
          return unless require_admin_dual_control!("admin.role_delete", { role_id: role.id, key: role.key })
          return unless require_step_up!("admin_role_change")
          snapshot = role_json(role)
          role.destroy!
          AuditLog.record!(action: "admin.role_deleted", actor: Current.user, metadata: { role: snapshot }, request: request)
          head :no_content
        end

        private
          def role_params
            params.permit(:key, :name, :description, permission_keys: [])
          end

          def role_json(role, users_count: nil)
            role.as_json(only: %i[id key name description system created_at]).merge(
              users_count: users_count.nil? ? role.users.count : users_count,
              permission_keys: role.permissions.sort_by(&:key).map(&:key)
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
