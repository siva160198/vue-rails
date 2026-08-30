module Api
  module V1
    class ReadinessController < ApplicationController
      allow_unauthenticated_access
      rate_limit to: 12, within: 1.minute, by: -> { request.remote_ip },
        with: -> { render_api_error("RATE_LIMITED", status: :too_many_requests) }

      before_action :require_readiness_token, if: -> { Rails.env.production? }

      def show
        ready = Rails.cache.fetch("operational-readiness-v1", expires_in: 5.seconds) { dependencies_ready? }

        if ready
          render json: { status: "ready" }
        else
          render_api_error("SERVICE_UNAVAILABLE", status: :service_unavailable)
        end
      end

      private
        def dependencies_ready?
          checks = {
            database: connection_ready?(ActiveRecord::Base),
            queue_database: connection_ready?(SolidQueue::Record),
            queue_workers: queue_workers_ready?,
            queue_latency: queue_latency_ready?,
            storage: storage_ready?,
            mail: mail_ready?
          }

          checks.values.all?
        end

        def require_readiness_token
          expected = ENV.fetch("READINESS_TOKEN")
          supplied = request.headers["X-Readiness-Token"].to_s
          valid = supplied.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
          render_api_error("RESOURCE_NOT_FOUND", status: :not_found) unless valid
        end

        def connection_ready?(record_class)
          record_class.connection.select_value("SELECT 1").to_i == 1
        rescue ActiveRecord::ActiveRecordError
          false
        end

        def queue_workers_ready?
          return true unless Rails.env.production?

          SolidQueue::Process.where(last_heartbeat_at: 2.minutes.ago..).exists?
        rescue ActiveRecord::ActiveRecordError
          false
        end

        def queue_latency_ready?
          oldest = SolidQueue::ReadyExecution.minimum(:created_at)
          oldest.nil? || oldest >= Integer(ENV.fetch("QUEUE_MAX_LATENCY_SECONDS", "300"), 10).seconds.ago
        rescue ActiveRecord::ActiveRecordError
          false
        end

        def storage_ready?
          ActiveStorage::Blob.service.exist?("readiness-probe-that-must-not-exist")
          true
        rescue StandardError
          false
        end

        def mail_ready?
          !Rails.env.production? || ENV.values_at("MAILER_FROM", "SMTP_ADDRESS").all?(&:present?)
        end
    end
  end
end
