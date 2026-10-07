module Reporting
  class DateRange
    class Invalid < StandardError; end
    attr_reader :start_date, :end_date
    def initialize(start_date: nil, end_date: nil, today: Date.current)
      @end_date = end_date.present? ? Date.iso8601(end_date.to_s) : today
      @start_date = start_date.present? ? Date.iso8601(start_date.to_s) : @end_date - 6
      raise Invalid unless (@end_date - @start_date).to_i.between?(0, 365) && @end_date <= today
    rescue Date::Error
      raise Invalid
    end
    def days
      (end_date - start_date).to_i + 1
    end
    def previous
      self.class.new(start_date: (start_date - days).iso8601, end_date: (start_date - 1).iso8601)
    end
    def interval
      # Explicit UTC half-open periods agree with PostgreSQL grouping and the JS dates.
      Time.utc(start_date.year, start_date.month, start_date.day)...Time.utc((end_date + 1).year, (end_date + 1).month, (end_date + 1).day)
    end
    def as_json(*)
      { start_date: start_date.iso8601, end_date: end_date.iso8601, days: days, timezone: "UTC" }
    end
  end
end
