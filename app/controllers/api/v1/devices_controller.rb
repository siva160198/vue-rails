module Api
  module V1
    class DevicesController < ApplicationController
      rate_limit to: 30, within: 1.minute, only: %i[destroy destroy_others], by: -> { Current.user.id }, with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def index
        authorize Session
        sessions, pagination = paginate_api(policy_scope(Session).active, search_columns: %w[ip_address user_agent], sortable_columns: %w[ip_address user_agent created_at last_seen_at expires_at], default_sort: :created_at, default_direction: :desc)
        render json: { sessions: sessions.map { |session| session_json(session) }, pagination: pagination }
      end

      def destroy
        session = policy_scope(Session).find(params[:id])
        authorize session
        current = session == Current.session
        AuditLog.record!(action: "session.revoked", actor: Current.user, auditable: session, metadata: { current: current }, request: request)
        session.destroy!
        cookies.delete(:session_id) if current
        render json: { current_session: current }
      end

      def destroy_others
        authorize Session, :destroy?
        return unless require_step_up!("sessions_revoke")
        removed = policy_scope(Session).where.not(id: Current.session.id).delete_all
        AuditLog.record!(action: "session.others_revoked", actor: Current.user, auditable: Current.user, metadata: { count: removed }, request: request)
        render json: { removed: removed }
      end

      private
        def session_json(session)
          session.as_json(only: %i[id ip_address user_agent created_at last_seen_at expires_at]).merge(current: session.id == Current.session.id)
        end
    end
  end
end
