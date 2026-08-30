require "test_helper"
require "yaml"

class OpenapiContractTest < ActiveSupport::TestCase
  setup do
    @document = YAML.safe_load_file(Rails.root.join("docs/openapi.yml"), aliases: true)
  end

  test "documents every concrete v1 API route and no stale route" do
    documented = @document.fetch("paths").flat_map do |path, operations|
      operations.keys.grep(/\A(get|post|patch|put|delete)\z/).map { |verb| [ verb.upcase, path ] }
    end.to_set
    routed = Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller].to_s.start_with?("api/v1/")

      path = route.path.spec.to_s.sub("(.:format)", "").gsub(/:([a-z_]+)/, '{\1}')
      route.verb.to_s.scan(/GET|POST|PATCH|PUT|DELETE/).map { |verb| [ verb == "PUT" ? "PATCH" : verb, path ] }
    end.flatten(1).to_set

    assert_equal routed, documented
  end

  test "operation ids are present and unique" do
    operations = @document.fetch("paths").values.flat_map do |path_item|
      path_item.filter_map { |verb, operation| operation if %w[get post patch put delete].include?(verb) }
    end
    operation_ids = operations.pluck("operationId")

    assert operation_ids.all?(&:present?)
    assert_equal operation_ids.uniq, operation_ids
  end

  test "every mutation documents the CSRF header" do
    mutations = @document.fetch("paths").flat_map do |path, path_item|
      path_item.filter_map { |verb, operation| [ path, verb, operation ] if %w[post patch put delete].include?(verb) }
    end

    mutations.each do |path, verb, operation|
      next if path == "/api/v1/csp_reports" # Browsers send CSP reports outside the application's fetch/CSRF flow.

      references = operation.fetch("parameters", []).filter_map { |parameter| parameter["$ref"] }
      assert_includes references, "#/components/parameters/CsrfToken", "#{verb.upcase} #{path} must document CSRF"
    end
  end

  test "every JSON success response has a response schema" do
    @document.fetch("paths").each do |path, path_item|
      path_item.each do |verb, operation|
        next unless %w[get post patch put delete].include?(verb)

        operation.fetch("responses").each do |status, response|
          next unless status.start_with?("2")
          next if status == "204"

          schemas = response.fetch("content", {}).values.filter_map { |media| media["schema"] }
          assert schemas.present?, "#{verb.upcase} #{path} response #{status} must define its response schema"
        end
      end
    end
  end

  test "shared pagination and error schemas match the API contract" do
    pagination = @document.dig("components", "schemas", "Pagination")
    error = @document.dig("components", "schemas", "ErrorEnvelope", "properties", "error")

    assert_equal %w[page per_page total total_pages], pagination.fetch("required")
    assert_equal 50, pagination.dig("properties", "per_page", "maximum")
    assert_equal %w[code message details], error.fetch("required")
    assert_equal "object", error.dig("properties", "details", "type")
  end
end
