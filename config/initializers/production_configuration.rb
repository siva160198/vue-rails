require Rails.root.join("lib/production_configuration")

if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  ProductionConfiguration.validate!
end
