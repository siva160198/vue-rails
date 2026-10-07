require "test_helper"
require "stringio"

class DataPipelinesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  class ImportAdapter
    attr_accessor :authorized
    attr_reader :keys
    def initialize
      @authorized = true
      @keys = []
    end
    def authorized?(_owner) = authorized
    def headers = %w[name email]
    def sample_rows = [ [ "Sample", "sample@invalid.test" ] ]
    def process!(row, owner:, idempotency_key:)
      raise DataPipelines::CsvDocument::Invalid, "INVALID_ROW" if row["name"] == "invalid"
      @keys << idempotency_key
    end
  end
  class IntegrationAdapter
    attr_accessor :error, :page, :authorized
    def initialize
      @authorized = true
      @page = { items: [ { id: "external-1", payload: { count: 5 } } ] }
    end
    def authorized?(_owner) = authorized
    def fetch_page(**)
      raise error if error
      page
    end
  end
  setup do
    @import = ImportAdapter.new
    @integration = IntegrationAdapter.new
    DataPipelines::Registry.imports.register("test_csv", -> { @import })
    DataPipelines::Registry.integrations.register("test_provider", -> { @integration })
  end
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  def submit(source = "name,email\nTest,test@invalid.test\n", key: "submission_key_12345")
    ImportRun.submit!(owner: users(:one), adapter_key: "test_csv", io: StringIO.new(source), submission_key: key)
  end
  def connection
    IntegrationConnection.create!(owner: users(:one), provider_key: "test_provider", credentials: { token: "secret-token" })
  end

  test "CSV supports quoted comma and semicolon UTF-8 with BOM" do
    source = DataPipelines::CsvDocument.read(StringIO.new("\uFEFFname;email\n\"Test; Name\";one@invalid.test\n"))
    assert_equal "Test; Name", DataPipelines::CsvDocument.rows(source, headers: %w[name email]).first["name"]
    assert_equal "Test, Name", DataPipelines::CsvDocument.rows("name,email\n\"Test, Name\",one@invalid.test\n", headers: %w[name email]).first["name"]
  end
  test "CSV rejects oversized envelopes invalid encoding headers columns cells and rows" do
    assert_raises(DataPipelines::CsvDocument::Invalid) { DataPipelines::CsvDocument.read(StringIO.new("\uFEFF" + "a" * DataPipelines::CsvDocument::MAX_BYTES)) }
    assert_raises(DataPipelines::CsvDocument::Invalid) { DataPipelines::CsvDocument.read(StringIO.new("\xff".b)) }
    assert_raises(DataPipelines::CsvDocument::Invalid) { DataPipelines::CsvDocument.read(StringIO.new("a\0")) }
    [ "name,name\na,b\n", "name,email\n", "other\nvalue\n", "name,email\n\"broken", "name,email\n#{'a' * 4001},b\n", "name,email\na,b,c\n", "name,email\n" + "a,b\n" * 2001 ].each do |source|
      assert_raises(DataPipelines::CsvDocument::Invalid) { DataPipelines::CsvDocument.rows(source, headers: %w[name email]) }
    end
    assert_raises(ArgumentError) { DataPipelines::Registry.new.register("../bad", -> { }) }
    assert_raises(ArgumentError) { DataPipelines::Registry.new.register("valid", Object.new) }
  end
  test "export neutralizes formulas and delimiter escaping" do
    values = [ "=1+1", " +cmd", "@sum", "\t1", "\uFF1D1", "safe,a" ]
    exported = CSV.parse(DataPipelines::CsvDocument.export([ "header" ], values.map { |value| [ value ] }))
    assert exported[1..5].all? { |row| row.first.start_with?("'") }
    assert_equal "safe,a", exported.last.first
  end
  test "submission is encrypted idempotent and only enqueues once" do
    assert_enqueued_jobs 1, only: ImportPipelineJob do
      run = submit
      assert run.source_ciphertext.start_with?(SecurityEncryptor::PREFIX)
      refute_includes run.source_ciphertext, "test@invalid.test"
      assert_equal run.id, submit.id
      assert_raises(ArgumentError) { submit("name,email\nOther,test@invalid.test\n") }
    end
    @import.authorized = false
    assert_raises(Pundit::NotAuthorizedError) { submit }
    assert_raises(KeyError) { ImportRun.submit!(owner: users(:one), adapter_key: "unregistered", io: StringIO.new(""), submission_key: "submission_key_12345") }
  end
  test "pending submissions are capped per owner" do
    3.times { |index| submit(key: "submission_key_#{index}_12345") }
    assert_raises(ArgumentError) { submit(key: "submission_key_4_12345") }
  end
  test "import chunks outcomes sample and failure exports without retaining row PII" do
    run = submit("name,email\n" + "Good,g@invalid.test\n" * 50 + "invalid,b@invalid.test\n")
    assert_enqueued_jobs 1, only: ImportPipelineJob do
      ImportPipelineJob.perform_now(run.id)
    end
    assert_equal "processing", run.reload.status
    assert_equal 50, run.processed_rows
    assert_nil run.source_ciphertext
    assert run.rows.where(status: "succeeded").all? { |row| row.payload_ciphertext.nil? }
    ImportPipelineJob.perform_now(run.id)
    assert_equal "completed", run.reload.status
    assert_equal 51, run.processed_rows
    assert_equal 1, run.failed_rows
    assert_equal 50, @import.keys.size
    ImportPipelineJob.perform_now(run.id)
    assert_equal 50, @import.keys.size
    assert_includes run.failures_csv, "51,CSV_ROW_INVALID"
    assert_equal "completed", run.progress[:status]
    assert_includes ImportRun.sample_csv(owner: users(:one), adapter_key: "test_csv"), "Sample"
  end
  test "malformed source revoked access and adapter failures safely terminate imports" do
    run = submit("broken")
    ImportPipelineJob.perform_now(run.id)
    assert_equal "CSV_INVALID_HEADERS", run.reload.failure_code
    revoked = submit(key: "submission_revoked_12345")
    @import.authorized = false
    ImportPipelineJob.perform_now(revoked.id)
    assert_equal "CSV_ACCESS_REVOKED", revoked.reload.failure_code
    assert_nil revoked.source_ciphertext
    @import.authorized = true
    broken = submit(key: "submission_broken_12345")
    @import.define_singleton_method(:process!) { |*args, **kwargs| raise "private row info" }
    ImportPipelineJob.perform_now(broken.id)
    assert_equal "CSV_PROCESSING_FAILED", broken.reload.failure_code
    assert_nil broken.source_ciphertext
    assert_raises(DataPipelines::CsvDocument::Invalid) { ImportRow.new(payload_ciphertext: nil).payload }
    ImportPipelineJob.perform_now(-1)
  end
  test "sync stores encrypted credentials and deduplicates local items" do
    record = connection
    refute_includes record.credentials_ciphertext, "secret-token"
    assert_equal "secret-token", record.credentials["token"]
    assert record.request_sync!
    refute record.request_sync!
    IntegrationSyncJob.perform_now(record.id)
    assert_equal "idle", record.reload.status
    assert_equal 1, record.items.count
    assert_equal({ "count" => 5 }, record.items.first.payload)
    record.request_sync!
    IntegrationSyncJob.perform_now(record.id)
    assert_equal 1, record.items.count
    assert record.reload.last_synced_at
  end
  test "paged sync persists opaque encrypted cursor and respects due time" do
    record = connection
    @integration.page = { items: [ { id: "one", payload: {} } ], next_cursor: "page-token" }
    record.request_sync!
    assert_enqueued_jobs 1, only: IntegrationSyncJob do
      IntegrationSyncJob.perform_now(record.id)
    end
    assert_equal "page-token", record.reload.cursor
    refute_includes record.cursor_ciphertext, "page-token"
    IntegrationSyncJob.perform_now(record.id)
    assert_equal 1, record.reload.processed_items
    travel 2.seconds do
      @integration.page = { items: [ { id: "two", payload: {} } ] }
      IntegrationSyncJob.perform_now(record.id)
    end
    assert_equal 2, record.items.count
    assert_nil record.reload.cursor
  end
  test "transient sync retries are bounded and never sleep in worker" do
    record = connection
    record.request_sync!
    @integration.error = DataPipelines::Sync::TransientFailure.new(retry_after: 99999)
    IntegrationSyncJob.perform_now(record.id)
    assert_equal "retry_wait", record.reload.status
    assert_equal 1, record.attempts
    2.times do
      travel 3601.seconds do
        record.reload.update!(next_sync_at: Time.current)
        IntegrationSyncJob.perform_now(record.id)
      end
    end
    assert_equal "failed", record.reload.status
    assert_equal 3, record.attempts
    assert_equal 3600, DataPipelines::Sync::TransientFailure.new(retry_after: 99999).retry_after
  end
  test "sync rejects oversized pages unauthorized access and expired authentication" do
    record = connection
    record.request_sync!
    @integration.error = DataPipelines::Sync::AuthenticationExpired.new
    IntegrationSyncJob.perform_now(record.id)
    assert_equal "reconnect_required", record.reload.status
    @integration.error = nil
    record.request_sync!
    @integration.authorized = false
    IntegrationSyncJob.perform_now(record.id)
    assert_equal "INTEGRATION_ACCESS_REVOKED", record.reload.failure_code
    assert_raises(Pundit::NotAuthorizedError) { record.request_sync! }
    @integration.authorized = true
    record.request_sync!
    @integration.page = { items: Array.new(101) { { id: "x", payload: {} } } }
    IntegrationSyncJob.perform_now(record.id)
    assert_equal "INTEGRATION_SYNC_FAILED", record.reload.failure_code
    assert_empty record.items
    IntegrationSyncJob.perform_now(-1)
  end
  test "recovery enqueue is bounded and terminal imports are retained briefly" do
    record = submit
    record.update!(updated_at: 1.hour.ago)
    assert_enqueued_jobs 1, only: ImportPipelineJob do
      PipelineMaintenanceJob.perform_now
    end
    assert_equal 1, record.reload.recovery_attempts
    record.update!(recovery_attempts: 3, updated_at: 1.hour.ago)
    PipelineMaintenanceJob.perform_now
    assert_equal "CSV_QUEUE_UNAVAILABLE", record.reload.failure_code
    record.update!(finished_at: 8.days.ago)
    PipelineMaintenanceJob.perform_now
    assert_nil ImportRun.find_by(id: record.id)
  end
  test "HTTP transport rejects redirects hosts and private or mapped addresses" do
    %w[127.0.0.1 10.0.0.1 169.254.169.254 ::1 ::ffff:127.0.0.1 192.0.2.1 invalid].each { |address| assert DataPipelines::HttpClient.blocked?(address) }
    refute DataPipelines::HttpClient.blocked?("8.8.8.8")
    assert_raises(ArgumentError) { DataPipelines::HttpClient.new(origin: "http://provider.test", allowed_hosts: [ "provider.test" ]) }
    client = DataPipelines::HttpClient.new(origin: "https://provider.test", allowed_hosts: [ "provider.test" ])
    assert_raises(ArgumentError) { client.get("https://other.test/path") }
  end
end
