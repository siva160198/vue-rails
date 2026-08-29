require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VueRails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1
    config.i18n.available_locales = %i[id en]
    config.i18n.default_locale = :id

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    frontend_origin = ENV["FRONTEND_ORIGIN"]
    frontend_origin ||= "http://localhost:5173" unless Rails.env.production?

    if frontend_origin
      config.middleware.insert_before 0, Rack::Cors do
        allow do
          origins frontend_origin
          resource "/api/*", headers: :any, expose: [ "X-Request-ID" ],
            methods: %i[get post put patch delete options head], credentials: true
        end
      end
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
