# Production Content Security Policy for the Rails-served Vue application.
if Rails.env.production?
  Rails.application.configure do
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.base_uri :self
      policy.connect_src :self
      policy.font_src :self, :https, :data
      policy.form_action :self
      policy.frame_ancestors :none
      policy.img_src :self, :https, :data
      policy.object_src :none
      policy.script_src :self
      policy.style_src :self, :https, :unsafe_inline
    end

    config.action_dispatch.default_headers.merge!(
      "Permissions-Policy" => "camera=(), microphone=(), geolocation=()",
      "Referrer-Policy" => "strict-origin-when-cross-origin",
      "X-Content-Type-Options" => "nosniff"
    )
  end
end
