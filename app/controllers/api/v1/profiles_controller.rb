module Api
  module V1
    class ProfilesController < ApplicationController
      def recovery_codes
        return render_api_error("INVALID_CREDENTIALS", status: :unauthorized) unless Current.user.authenticate(params[:password])

        codes = Current.user.regenerate_recovery_codes!
        AuditLog.record!(action: "profile.recovery_codes_regenerated", actor: Current.user, auditable: Current.user, request: request)
        render json: { recovery_codes: codes }
      end

      def update
        Current.user.avatar.attach(params.require(:avatar))
        if Current.user.valid?
          AuditLog.record!(action: "profile.avatar_updated", actor: Current.user, auditable: Current.user, request: request)
          render json: { avatar_url: rails_blob_path(Current.user.avatar, only_path: true) }
        else
          Current.user.avatar.purge
          render_validation_error(Current.user)
        end
      end

      def destroy
        Current.user.avatar.purge
        AuditLog.record!(action: "profile.avatar_removed", actor: Current.user, auditable: Current.user, request: request)
        head :no_content
      end
    end
  end
end
