module Api
  module V1
    class CsrfController < ApplicationController
      allow_unauthenticated_access

      def show
        render json: { token: form_authenticity_token }
      end
    end
  end
end
