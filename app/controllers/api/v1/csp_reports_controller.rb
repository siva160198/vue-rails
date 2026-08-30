module Api
  module V1
    class CspReportsController < ApplicationController
      allow_unauthenticated_access only: :create
      skip_forgery_protection only: :create
      rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

      def create
        report = params["csp-report"] || params[:body] || {}
        Rails.logger.warn({ event: "csp_violation", request_id: request.request_id, directive: report["violated-directive"], blocked: report["blocked-uri"].to_s.split("?").first }.to_json)
        head :no_content
      end
    end
  end
end
