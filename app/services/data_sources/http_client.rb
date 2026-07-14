require "faraday"
require "faraday/retry"

module DataSources
  # Thin Faraday wrapper shared by adapters: JSON parsing, per-provider timeouts,
  # and bounded retry with backoff on transient 429/5xx/network errors so one
  # flaky provider doesn't blank the dashboard. Config comes from data_sources.yml.
  class HttpClient
    RETRIABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    def initialize(base_url:, headers: {}, open_timeout: 5, timeout: 15, max_retries: 2)
      # Trailing slash + relative paths so the base path (e.g. "/v1") is preserved.
      # Without it, Faraday treats a leading-slash path as absolute and drops "/v1".
      base_url = "#{base_url}/" unless base_url.end_with?("/")
      @conn = Faraday.new(url: base_url) do |f|
        f.request :retry,
          max: max_retries,
          interval: 0.3,
          backoff_factor: 2,
          retry_statuses: RETRIABLE_STATUSES,
          methods: %i[get]
        f.response :json, content_type: /\bjson$/
        f.headers.update(headers)
        f.options.open_timeout = open_timeout
        f.options.timeout = timeout
      end
    end

    # GET a path with query params; returns the parsed JSON body.
    # Raises DataSources::ProviderError on non-2xx or transport failure.
    def get(path, params = {})
      response = @conn.get(path.delete_prefix("/"), params)
      unless response.success?
        raise ProviderError, "GET #{path} failed: HTTP #{response.status} #{truncate(response.body)}"
      end

      response.body
    rescue Faraday::Error => e
      raise ProviderError, "GET #{path} failed: #{e.class} #{e.message}"
    end

    private

    def truncate(body, limit = 200)
      body.to_s[0, limit]
    end
  end
end
