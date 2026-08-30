# Production Content Security Policy for the Rails-served Vue application.
if Rails.env.production?
  Rails.application.configure do
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.base_uri :self
      policy.connect_src :self, "https://challenges.cloudflare.com"
      policy.font_src :self, :https, :data
      policy.form_action :self
      policy.frame_ancestors :none
      policy.frame_src :self, "https://challenges.cloudflare.com"
      policy.img_src :self, :data
      policy.object_src :none
      policy.script_src :self, "https://challenges.cloudflare.com"
      policy.style_src :self, :https
      policy.style_src_attr :unsafe_inline
      policy.report_uri "/api/v1/csp_reports"
    end

    config.action_dispatch.default_headers.merge!(
      "Permissions-Policy" => "camera=(), microphone=(), geolocation=()",
      "Referrer-Policy" => "strict-origin-when-cross-origin",
      "X-Content-Type-Options" => "nosniff",
      "Cross-Origin-Opener-Policy" => "same-origin",
      "Cross-Origin-Resource-Policy" => "same-origin"
    )
  end
end
