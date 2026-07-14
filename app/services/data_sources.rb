# Namespace for external data-source adapters (DeBank, Bitcoin, Solana …).
#
# Every provider implements the same interface (DataSources::Base) and returns a
# normalized DataSources::Result, so the refresh/read side never depends on which
# provider is behind a chain. This file also exposes provider config loaded from
# config/data_sources.yml — see DataSources.config(:debank).

module DataSources
  CONFIG_PATH = Rails.root.join("config", "data_sources.yml")

  # Raised when an adapter is asked to fetch but no API key is configured.
  class MissingCredentialError < StandardError; end

  # Raised when a provider returns an error / unusable response.
  class ProviderError < StandardError; end

  # Immutable per-provider settings, with the API key already resolved. Unknown
  # YAML keys are ignored so we only surface what adapters actually consume.
  ProviderConfig = Data.define(:base_url, :access_key, :open_timeout, :timeout, :max_retries)

  class << self
    # Config for one provider (e.g. :debank) as a ProviderConfig, with the API key
    # already resolved from ENV or Rails credentials.
    def config(provider)
      configs.fetch(provider.to_sym) do
        raise KeyError, "No data source configured for #{provider.inspect} in data_sources.yml"
      end
    end

    # Test seam: forget memoized config so a stubbed ENV/key takes effect.
    def reset_config!
      @configs = nil
    end

    private

    def configs
      @configs ||= build_configs
    end

    def build_configs
      raw = YAML.load_file(CONFIG_PATH, aliases: true)
      env = raw.fetch(Rails.env, raw.fetch("default"))
      env.transform_keys(&:to_sym).transform_values do |settings|
        ProviderConfig.new(
          base_url: settings["base_url"],
          access_key: resolve_key(settings),
          open_timeout: settings["open_timeout"],
          timeout: settings["timeout"],
          max_retries: settings["max_retries"]
        )
      end
    end

    # ENV wins (Docker/.env), then Rails credentials as a fallback. Blank is OK
    # until an adapter actually makes a call — it raises then, not at boot.
    # e.g. DEBANK_ACCESS_KEY -> ENV["DEBANK_ACCESS_KEY"] || credentials.debank.access_key
    def resolve_key(settings)
      env_name = settings["access_key_env"]
      return nil if env_name.blank?

      ENV[env_name].presence ||
        Rails.application.credentials.dig(*env_name.downcase.split("_", 2).map(&:to_sym))
    end
  end
end
