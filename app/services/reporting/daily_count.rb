module Reporting
  class DailyCount
    def initialize(scope:, range:, timestamp: :created_at, allowed_timestamps: [ :created_at ])
      @scope, @range, @timestamp = scope, range, timestamp.to_s
      raise ArgumentError, "Unapproved timestamp" unless allowed_timestamps.map(&:to_s).include?(@timestamp) && scope.klass.columns_hash[@timestamp]&.type.in?(%i[datetime timestamp])
    end
    def call
      previous_range = @range.previous
      current = series(@range)
      previous = series(previous_range)
      {
        range: @range.as_json, previous_range: previous_range.as_json,
        current: current, previous: previous,
        comparison: Comparison.call(current: current.sum { |point| point[:value] }, previous: previous.sum { |point| point[:value] })
      }
    end

    private
      def series(range)
        connection = @scope.klass.connection
        column = "#{connection.quote_table_name(@scope.klass.table_name)}.#{connection.quote_column_name(@timestamp)}"
        # Aggregation stays in PostgreSQL, never instantiate all source records.
        # Rails datetime columns are timestamp-without-time-zone in UTC.
        counts = @scope.where(@timestamp => range.interval).unscope(:order).group(Arel.sql("DATE(#{column})")).count
        (range.start_date..range.end_date).map { |date| { date: date.iso8601, value: counts.fetch(date, 0) } }
      end
  end
end
