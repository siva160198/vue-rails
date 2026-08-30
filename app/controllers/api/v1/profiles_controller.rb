module Api
  module V1
    class ProfilesController < ApplicationController
      def show
        authorize :profile
        render json: { profile: profile_json }
      end

      def update
        authorize :profile
        return update_avatar if params[:avatar].present?

        attributes = profile_params.to_h.transform_values { |value| value.to_s.strip.presence }
        return render json: { profile: profile_json, unchanged: true } if attributes.all? { |key, value| Current.user.public_send(key) == value }

        if Current.user.update(attributes)
          AuditLog.record!(action: "profile.updated", actor: Current.user, auditable: Current.user, metadata: { fields: attributes.keys }, request: request)
          render json: { profile: profile_json, unchanged: false }
        else
          render_validation_error(Current.user)
        end
      end

      def destroy
        authorize :profile
        return head :no_content unless Current.user.avatar.attached?

        Current.user.avatar.purge
        AuditLog.record!(action: "profile.avatar_removed", actor: Current.user, auditable: Current.user, request: request)
        head :no_content
      end

      private
        def update_avatar
          processed = AvatarProcessor.call(params.require(:avatar))
          Current.user.avatar.attach(io: processed.io, filename: processed.filename, content_type: processed.content_type)
          Current.user.save!
          AuditLog.record!(action: "profile.avatar_updated", actor: Current.user, auditable: Current.user, metadata: { bytes: processed.byte_size, format: "avif" }, request: request)
          render json: { avatar_url: rails_blob_path(Current.user.avatar, only_path: true), byte_size: processed.byte_size, content_type: processed.content_type }
        rescue AvatarProcessor::InvalidImage => error
          message = I18n.t("api.errors.#{error.message}", default: I18n.t("api.errors.avatar_invalid"))
          render_api_error("INVALID_AVATAR", message: message, details: { avatar: [ message ] }, status: :unprocessable_content)
        end

        def profile_params
          params.permit(:first_name, :last_name, :phone)
        end

        def profile_json
          Current.user.as_json(only: %i[id email_address role active email_verified_at created_at first_name last_name phone]).merge(
            avatar_url: Current.user.avatar.attached? ? rails_blob_path(Current.user.avatar, only_path: true) : nil
          )
        end
    end
  end
end
