module Api
  module V1
    module Admin
      class UsersController < ApplicationController
        rate_limit to: 60, within: 1.minute, only: %i[create update],
          by: -> { Current.user&.id || request.remote_ip },
          with: -> { render_api_error("USER_RATE_LIMITED", status: :too_many_requests) }

        def index
          authorize User
          users, pagination = paginate_cursor_api(
            policy_scope(User),
            search_columns: %w[email_address],
            sortable_columns: %w[email_address role active login_otp_required email_verified_at created_at],
            default_sort: :created_at,
            default_direction: :desc
          )

          render json: { users: users.map { |user| user_json(user) }, roles: role_options, pagination: pagination }
        end

        def update
          user = User.find(params[:id])
          authorize user
          attributes = requested_attributes
          if user == Current.user && (attributes.key?("role") || attributes["active"] == false || attributes.key?("login_otp_required"))
            return render_api_error("CANNOT_CHANGE_OWN_ADMIN_ACCESS", status: :forbidden)
          end
          previous = user.slice("role", "active", "login_otp_required")
          user.assign_attributes(attributes)
          return render json: { user: user_json(user), unchanged: true } unless user.changed?
          return render_validation_error(user) unless user.valid?
          login_otp_changed = user.will_save_change_to_login_otp_required?
          return unless require_admin_dual_control!("admin.user_access", { user_id: user.id, role: user.role, active: user.active, login_otp_required: user.login_otp_required })
          return unless require_step_up!("admin_user_update")
          return render_last_admin_error if removes_last_admin?(user, attributes)

          User.transaction do
            user.save!
            if !user.active? || login_otp_changed
              user.sessions.destroy_all
              user.increment!(:authentication_version) if login_otp_changed
            end
            AuditLog.record!(
              action: "admin.user_updated",
              actor: Current.user,
              auditable: user,
              metadata: { before: previous, after: user.slice("role", "active", "login_otp_required") },
              request: request
            )
          end
          if login_otp_changed
            SecurityNotificationMailer.with(user: user, security_event: "login OTP").security_setting_changed.deliver_later
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
            roles: role_options
          }
        end

        def new
          authorize User
          render json: { roles: role_options }
        end

        def create
          authorize User
          user = User.new
          user.email_address = params[:email_address]
          user.first_name = params[:first_name]
          user.last_name = params[:last_name]
          user.phone = params[:phone]
          user.role = params[:role]
          user.active = boolean_param(:active, default: true)
          user.login_otp_required = boolean_param(:login_otp_required, default: true)
          user.password = SecureRandom.base64(48)
          user.password_confirmation = user.password
          user.invited_at = Time.current
          return render_validation_error(user) unless user.valid?
          approval_payload = {
            email_digest: EmailPrivacyDigest.call(user.email_address),
            role: user.role,
            active: user.active,
            login_otp_required: user.login_otp_required
          }
          return unless require_admin_dual_control!("admin.user_create", approval_payload)
          return unless require_step_up!("admin_user_create")

          User.transaction do
            user.save!
            AuditLog.record!(action: "admin.user_created", actor: Current.user, auditable: user,
              metadata: { role: user.role, active: user.active, login_otp_required: user.login_otp_required }, request: request)
          end
          PasswordsMailer.invitation(user).deliver_later
          render json: { user: user_json(user) }, status: :created
        rescue ActiveRecord::RecordInvalid
          render_validation_error(user)
        end

        private
          def requested_attributes
            {}.tap do |attributes|
              attributes["role"] = params[:role] if params.key?(:role)
              attributes["active"] = ActiveModel::Type::Boolean.new.cast(params[:active]) if params.key?(:active)
              attributes["login_otp_required"] = ActiveModel::Type::Boolean.new.cast(params[:login_otp_required]) if params.key?(:login_otp_required)
            end
          end

          def boolean_param(key, default:)
            return default unless params.key?(key)

            ActiveModel::Type::Boolean.new.cast(params[key])
          end

          def role_options
            required_roles = ENV.fetch("MFA_REQUIRED_ROLES", ENV.fetch("ADMIN_MFA_REQUIRED", "true") == "true" ? "admin" : "").split(",").map(&:strip)
            Role.order(:name).pluck(:key, :name).map do |key, name|
              { key: key, name: name, login_otp_required: required_roles.include?(key) }
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
            user.as_json(only: %i[id email_address role active login_otp_required email_verified_at created_at])
          end
      end
    end
  end
end
