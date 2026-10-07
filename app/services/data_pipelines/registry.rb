module DataPipelines
  class Registry
    def self.imports
      @imports ||= new
    end
    def self.integrations
      @integrations ||= new
    end
    # Factories are code-defined and registered at boot; never constantize client input.
    def initialize
      @factories = {}
    end

    def register(key, factory)
      raise ArgumentError, "Invalid adapter key" unless key.to_s.match?(/\A[a-z][a-z0-9_]{0,63}\z/)
      raise ArgumentError, "Factory must be callable" unless factory.respond_to?(:call)
      @factories[key.to_s] = factory
    end

    def fetch(key)
      @factories.fetch(key.to_s).call
    end
  end
end
