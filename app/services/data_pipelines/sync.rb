module DataPipelines
  module Sync
    class AuthenticationExpired < StandardError; end
    class TransientFailure < StandardError
      attr_reader :retry_after
      def initialize(retry_after: 30)
        @retry_after = Integer(retry_after).clamp(1, 3600)
        super("INTEGRATION_TEMPORARY_FAILURE")
      end
    end
    PAGE_SIZE = 100
    MAX_ITEMS = 10_000
    MAX_PAYLOAD_BYTES = 16_384
  end
end
