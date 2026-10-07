# Run using bin/ci

CI.run do
  step "Runtime: Node", "ruby bin/check_node"
  next unless success?

  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  # Includes test/contracts/openapi_contract_test.rb once as part of the full suite.
  step "Tests: Rails + OpenAPI contract", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  step "Tests: Vue", "npm test --prefix frontend"
  step "Build: Vue", "npm run build --prefix frontend"

  if ENV["CI_E2E"] == "true"
    step "Tests: Playwright", "npm run test:e2e --prefix frontend"
  else
    heading "Tests: Playwright skipped", "Run CI_E2E=true bin/ci to include browser tests.", type: :subtitle
  end

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
