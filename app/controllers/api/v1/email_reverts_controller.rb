module Api
  module V1
    class EmailRevertsController < ApplicationController
      allow_unauthenticated_access only: :create
      rate_limit to: 5, within: 15.minutes, with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      def create
        payload = Rails.application.message_verifier(:email_revert).verify(params[:token])
        user = User.find(payload.fetch("user_id"))
        valid = user.pending_email_revert_expires_at&.future? &&
          ActiveSupport::SecurityUtils.secure_compare(user.pending_email_revert_digest.to_s, Digest::SHA256.hexdigest(payload.fetch("token")))
        return invalid_revert unless valid

        previous_email = SecurityEncryptor.decrypt(user.pending_email_revert_address, purpose: "email-revert")
        return invalid_revert if previous_email.blank? || User.where.not(id: user.id).exists?(email_address: previous_email)

        user.update!(email_address: previous_email, email_verified_at: Time.current, pending_email_revert_digest: nil, pending_email_revert_address: nil, pending_email_revert_expires_at: nil)
        user.sessions.delete_all
        user.increment!(:authentication_version)
        AuditLog.record!(action: "account.email_change_reverted", actor: user, auditable: user, request: request)
        render json: { reverted: true }
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound, KeyError
        invalid_revert
      end

      private
        def invalid_revert
          render_api_error("INVALID_EMAIL_REVERT_TOKEN", status: :unauthorized)
        end
    end
  end
end
