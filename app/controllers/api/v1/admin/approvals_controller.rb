module Api
  module V1
    module Admin
      class ApprovalsController < ApplicationController
        def index
          authorize AdminApproval
          approvals, pagination = paginate_api(policy_scope(AdminApproval).pending.includes(:requester), search_columns: %w[action_key], sortable_columns: %w[action_key created_at expires_at], default_sort: :created_at, default_direction: :desc)
          render json: { approvals: approvals.map { |approval| approval_json(approval) }, pagination: pagination }
        end

        def update
          approval = policy_scope(AdminApproval).pending.find(params[:id])
          authorize approval
          return unless require_step_up!("admin_approval")

          approved = approval.with_lock do
            approval.reload
            next false unless approval.approved_at.nil? && approval.consumed_at.nil? && approval.expires_at.future?

            approval.update!(approver: Current.user, approved_at: Time.current)
            true
          end
          return render_api_error("RESOURCE_NOT_FOUND", status: :not_found) unless approved
          AuditLog.record!(action: "admin.approval_granted", actor: Current.user, metadata: { approval_id: approval.id, requester_id: approval.requester_id, action_key: approval.action_key }, request: request)
          render json: { approval: approval_json(approval) }
        end

        private
          def approval_json(approval)
            approval.as_json(only: %i[id action_key payload_summary created_at expires_at approved_at]).merge(requester_email: approval.requester.email_address)
          end
      end
    end
  end
end
