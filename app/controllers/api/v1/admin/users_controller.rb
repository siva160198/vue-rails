module Api
  module V1
    module Admin
      class UsersController < ApplicationController
        rate_limit to: 60, within: 1.minute, only: :update,
          by: -> { Current.user&.id || request.remote_ip },
          with: -> { render_api_error("USER_RATE_LIMITED", status: :too_many_requests) }

        def index
          authorize User
          users, pagination = paginate_api(
            policy_scope(User),
            search_columns: %w[email_address],
            sortable_columns: %w[email_address role active email_verified_at created_at],
            default_sort: :created_at,
            default_direction: :desc
          )

          render json: { users: users.map { |user| user_json(user) }, roles: Role.order(:name).pluck(:key, :name).map { |key, name| { key: key, name: name } }, pagination: pagination }
        end

        def update
          user = User.find(params[:id])
          authorize user
          attributes = requested_attributes
          if user == Current.user && (attributes.key?("role") || attributes["active"] == false)
            return render_api_error("CANNOT_CHANGE_OWN_ADMIN_ACCESS", status: :forbidden)
          end
          previous = user.slice("role", "active")
          user.assign_attributes(attributes)
          return render json: { user: user_json(user), unchanged: true } unless user.changed?
          return render_validation_error(user) unless user.valid?
          return unless require_admin_dual_control!("admin.user_access", { user_id: user.id, role: user.role, active: user.active })
          return unless require_step_up!("admin_user_update")
          return render_last_admin_error if removes_last_admin?(user, attributes)

          User.transaction do
            user.save!
            user.sessions.destroy_all unless user.active?
            AuditLog.record!(
              action: "admin.user_updated",
              actor: Current.user,
              auditable: user,
              metadata: { before: previous, after: user.slice("role", "active") },
              request: request
            )
          end

          render json: { user: user_json(user) }
        rescue ActiveRecord::RecordInvalid
          render_validation_error(user)
        end

        def show
          user = User.find(params[:id])
          authorize user
          render json: {
            user: user_json(user),
            roles: Role.order(:name).pluck(:key, :name).map { |key, name| { key: key, name: name } }
          }
        end

        private
          def requested_attributes
            {}.tap do |attributes|
              attributes["role"] = params[:role] if params.key?(:role)
              attributes["active"] = ActiveModel::Type::Boolean.new.cast(params[:active]) if params.key?(:active)
            end
          end

          def removes_last_admin?(user, attributes)
            return false unless user.role_in_database == "admin" && user.active_in_database
            return false if attributes.fetch("role", user.role) == "admin" && ActiveModel::Type::Boolean.new.cast(attributes.fetch("active", user.active?))

            User.admin.where(active: true).count == 1
          end

          def render_last_admin_error
            render_api_error("LAST_ACTIVE_ADMIN_REQUIRED", status: :unprocessable_content)
          end

          def user_json(user)
            user.as_json(only: %i[id email_address role active email_verified_at created_at])
          end
      end
    end
  end
end
