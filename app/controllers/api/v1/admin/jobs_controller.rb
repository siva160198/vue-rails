module Api
  module V1
    module Admin
      class JobsController < ApplicationController
        def index
          authorize :job_monitor
          failures, pagination = paginate_api(
            SolidQueue::FailedExecution.includes(:job),
            search_columns: %w[error],
            sortable_columns: %w[created_at],
            default_sort: :created_at,
            default_direction: :desc
          )
          render json: { metrics: metrics, failures: failures.map { |failure| failure_json(failure) }, pagination: pagination }
        end

        def retry
          authorize :job_monitor, :update?
          failure = SolidQueue::FailedExecution.find(params[:id])
          job_id = failure.job_id
          failure.retry
          record_action("job.retried", job_id)
          render json: { id: job_id }
        end

        def destroy
          authorize :job_monitor
          failure = SolidQueue::FailedExecution.find(params[:id])
          job_id = failure.job_id
          failure.discard
          record_action("job.discarded", job_id)
          head :no_content
        end

        private
          def metrics
            {
              ready: SolidQueue::ReadyExecution.count,
              scheduled: SolidQueue::ScheduledExecution.count,
              claimed: SolidQueue::ClaimedExecution.count,
              failed: SolidQueue::FailedExecution.count,
              oldest_ready_at: SolidQueue::ReadyExecution.minimum(:created_at)
            }
          end

          def failure_json(failure)
            { id: failure.id, job_id: failure.job_id, class_name: failure.job.class_name, queue_name: failure.job.queue_name, exception_class: failure.exception_class, message: failure.message, created_at: failure.created_at }
          end

          def record_action(action, job_id)
            AuditLog.record!(action: action, actor: Current.user, metadata: { job_id: job_id }, request: request)
          end
      end
    end
  end
end
