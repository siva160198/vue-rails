require "test_helper"

class MailDeliveryJobTest < ActiveJob::TestCase
  test "mail delivery jobs use the dedicated mailers queue" do
    job = MailDeliveryJob.new("LoginOtpMailer", "verification_code", "deliver_now", params: {}, args: [])

    assert_equal "mailers", job.queue_name
  end

  test "mailer delivery_later enqueues the custom delivery job" do
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    assert_enqueued_with(job: MailDeliveryJob, queue: "mailers") do
      LoginOtpMailer.with(user: users(:one), code: "123456").verification_code.deliver_later
    end
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end
end
