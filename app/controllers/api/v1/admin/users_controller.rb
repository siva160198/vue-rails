module Api
  module V1
    module Admin
      class UsersController < ApplicationController
        rate_limit to: 60, within: 1.minute, only: :update,
          by: -> { Current.user&.id || request.remote_ip },
          with: -> { render json: { error: "Terlalu banyak perubahan. Coba lagi sebentar." }, status: :too_many_requests }

        def index
          authorize User
          users = policy_scope(User).order(created_at: :desc)
          users = users.where("email_address ILIKE ?", "%#{User.sanitize_sql_like(params[:search])}%") if params[:search].present?
          users = users.limit(100)

          render json: { users: users.map { |user| user_json(user) }, roles: Role.order(:name).pluck(:key, :name).map { |key, name| { key: key, name: name } } }
        end

        def update
          user = User.find(params[:id])
          authorize user
          attributes = requested_attributes
          return render_last_admin_error if removes_last_admin?(user, attributes)

          previous = user.slice("role", "active")
          user.assign_attributes(attributes)
          return render json: { user: user_json(user), unchanged: true } unless user.changed?

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
          render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        private
          def requested_attributes
            {}.tap do |attributes|
              attributes["role"] = params[:role] if params.key?(:role)
              attributes["active"] = ActiveModel::Type::Boolean.new.cast(params[:active]) if params.key?(:active)
            end
          end

          def removes_last_admin?(user, attributes)
            return false unless user.admin? && user.active?
            return false if attributes.fetch("role", user.role) == "admin" && ActiveModel::Type::Boolean.new.cast(attributes.fetch("active", user.active?))

            User.admin.where(active: true).count == 1
          end

          def render_last_admin_error
            render json: { error: "Admin aktif terakhir tidak dapat dinonaktifkan atau diturunkan rolenya." }, status: :unprocessable_content
          end

          def user_json(user)
            user.as_json(only: %i[id email_address role active email_verified_at created_at])
          end
      end
    end
  end
end
