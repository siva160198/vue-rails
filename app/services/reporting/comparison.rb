module Reporting
  class Comparison
    def self.call(current:, previous:, lower_is_better: false)
      change = current - previous
      {
        current: current, previous: previous, difference: change,
        percentage: previous.zero? ? (current.zero? ? 0.0 : nil) : (change.to_f / previous.abs * 100).round(2),
        trend: change.zero? ? "unchanged" : change.positive? ? "up" : "down",
        favorable: change.zero? ? nil : lower_is_better ? change.negative? : change.positive?
      }
    end
  end
end
