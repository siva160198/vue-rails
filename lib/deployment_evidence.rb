require "yaml"
require "date"

class DeploymentEvidence
  REQUIRED = %w[scope_approved_by security_owner operations_owner risk_review_approved_by audit_sink_tested_on alert_delivery_tested_on offsite_backup_verified_on restore_drill_on next_review_on rpo_minutes rto_minutes].freeze
  def self.problems(document, today: Date.today)
    problems = REQUIRED.select { |key| document[key].to_s.strip.empty? }
    %w[audit_sink_tested_on alert_delivery_tested_on offsite_backup_verified_on restore_drill_on].each do |key|
      value = Date.iso8601(document[key].to_s) rescue nil
      problems << key unless value && value <= today && value >= today - 31
    end
    review = Date.iso8601(document["next_review_on"].to_s) rescue nil
    problems << "next_review_on" unless review && review > today
    problems << "risks_accepted" unless document["risks_accepted"] == true
    %w[rpo_minutes rto_minutes].each { |key| problems << key unless document[key].is_a?(Integer) && document[key].positive? }
    problems.uniq
  end
end
