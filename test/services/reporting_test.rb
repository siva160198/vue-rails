require "test_helper"
class ReportingTest < ActiveSupport::TestCase
  test "ranges are inclusive bounded UTC and previous period has equal days" do
    range = Reporting::DateRange.new(start_date: "2026-03-01", end_date: "2026-03-07")
    assert_equal 7, range.days
    assert_equal "2026-02-22", range.previous.start_date.iso8601
    assert_equal Time.utc(2026, 3, 8), range.interval.end
    %w[invalid 2026-02-30].each { |value| assert_raises(Reporting::DateRange::Invalid) { Reporting::DateRange.new(start_date: value) } }
    assert_raises(Reporting::DateRange::Invalid) { Reporting::DateRange.new(start_date: "2020-01-01") }
    assert_raises(Reporting::DateRange::Invalid) { Reporting::DateRange.new(end_date: 1.day.from_now.to_date.iso8601) }
  end
  test "comparison handles zeros negatives and inverse success semantics" do
    assert_nil Reporting::Comparison.call(current: 2, previous: 0)[:percentage]
    assert_equal 0.0, Reporting::Comparison.call(current: 0, previous: 0)[:percentage]
    assert_nil Reporting::Comparison.call(current: 0, previous: 0)[:favorable]
    assert Reporting::Comparison.call(current: 2, previous: 3, lower_is_better: true)[:favorable]
    refute Reporting::Comparison.call(current: 2, previous: 3)[:favorable]
    assert_equal 50.0, Reporting::Comparison.call(current: -1, previous: -2)[:percentage]
  end
  test "daily aggregates reconcile with scoped counts and whitelist timestamp" do
    range = Reporting::DateRange.new
    result = Reporting::DailyCount.new(scope: User.where(id: users(:one).id), range: range).call
    assert_equal 7, result[:current].size
    assert_equal User.where(id: users(:one).id, created_at: range.interval).count, result[:comparison][:current]
    assert_equal result[:current].sum { |point| point[:value] }, result[:comparison][:current]
    assert_raises(ArgumentError) { Reporting::DailyCount.new(scope: User.all, range: range, timestamp: "created_at);DROP TABLE users;") }
  end
end
