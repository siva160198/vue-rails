require "test_helper"

class Api::V1::Admin::JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @job = SolidQueue::Job.create!(queue_name: "default", class_name: "ExampleJob", arguments: {}, active_job_id: SecureRandom.uuid, scheduled_at: Time.current)
    @failure = SolidQueue::FailedExecution.create!(job: @job, error: { exception_class: "RuntimeError", message: "boom", backtrace: [] })
  end

  teardown { SolidQueue::Job.where(id: @job.id).delete_all }

  test "lists queue metrics and paginated failures" do
    get api_v1_admin_jobs_url, as: :json

    assert_response :success
    assert_equal @failure.id, response.parsed_body.dig("failures", 0, "id")
    assert_equal 1, response.parsed_body.dig("pagination", "total")
    assert response.parsed_body.fetch("metrics").key?("failed")
  end

  test "retries a failed job and records an audit" do
    assert_difference("AuditLog.count", 1) { post retry_api_v1_admin_job_url(@failure), as: :json }

    assert_response :success
    assert_not SolidQueue::FailedExecution.exists?(@failure.id)
    assert_equal "job.retried", AuditLog.last.action
  end

  test "discards a failed job" do
    delete api_v1_admin_job_url(@failure), as: :json

    assert_response :no_content
    assert_not SolidQueue::Job.exists?(@job.id)
  end

  test "member cannot inspect the queue" do
    sign_in_as users(:two)
    get api_v1_admin_jobs_url, as: :json

    assert_response :forbidden
    assert_api_error("FORBIDDEN")
  end
end
