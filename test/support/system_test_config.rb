require "active_support/core_ext/object/blank"
require "net/protocol"
require "capybara"
require "minitest/retry"

module SystemTestConfig
  FAST_PROFILE = "FAST"
  ROBUST_PROFILE = "ROBUST"

  PROFILES = {
    FAST_PROFILE => {
      wait_time: 2,
      retries: 0,
    }.freeze,
    ROBUST_PROFILE => {
      wait_time: 15,
      retries: 6,
    }.freeze,
  }.freeze

  DEFAULT_RETRY_EXCEPTIONS = [Net::ReadTimeout, Capybara::ModalNotFound].freeze
  BANNER_DIVIDER = "-" * 60

  Configuration = Data.define(:profile, :wait_time, :retries, :warnings) do
    def fast?
      profile == FAST_PROFILE
    end

    def robust?
      profile == ROBUST_PROFILE
    end

    def summary_line
      "Active Test Profile: #{profile} (Wait: #{wait_time}s, Retries: #{retries})"
    end

    def banner
      "#{BANNER_DIVIDER}\n#{summary_line}\n#{BANNER_DIVIDER}"
    end
  end

  class << self
    attr_reader :current

    def robust_wait_time
      PROFILES.fetch(ROBUST_PROFILE)[:wait_time]
    end

    def resolve(env = ENV)
      warnings = []
      profile = resolve_profile(env, warnings)
      defaults = PROFILES.fetch(profile)

      wait_time = resolve_wait_time(env, defaults[:wait_time], warnings)
      retries = resolve_retries(env, defaults[:retries], warnings)

      Configuration.new(
        profile: profile,
        wait_time: wait_time,
        retries: retries,
        warnings: warnings.freeze,
      )
    end

    def apply!(env: ENV, io: nil)
      config = resolve(env)
      @current = config

      config.warnings.each do |message|
        if io
          io.puts(message)
        else
          warn(message)
        end
      end

      Capybara.default_max_wait_time = config.wait_time
      Minitest::Retry.use!(
        retry_count: config.retries,
        io: io || $stdout,
        verbose: true,
        exceptions_to_retry: DEFAULT_RETRY_EXCEPTIONS,
      )

      (io || $stdout).puts(config.banner)

      config
    end

    private

    def resolve_profile(env, warnings)
      raw_profile = env["TEST_PROFILE"]&.to_s&.strip

      if raw_profile.present?
        normalized = raw_profile.upcase
        return normalized if PROFILES.key?(normalized)

        warnings << "[SystemTestConfig] Warning: Unrecognized TEST_PROFILE=#{raw_profile.inspect}. Falling back to #{ROBUST_PROFILE} profile."
        return ROBUST_PROFILE
      end

      env["CI"].present? ? ROBUST_PROFILE : FAST_PROFILE
    end

    def resolve_wait_time(env, fallback, warnings)
      raw_value = env["CAPYBARA_DEFAULT_MAX_WAIT_TIME"]&.to_s&.strip
      return fallback unless raw_value.present?

      parsed = raw_value.include?(".") ? Float(raw_value) : Integer(raw_value, 10)
      if parsed >= 0
        parsed
      else
        warnings << "[SystemTestConfig] Warning: Invalid CAPYBARA_DEFAULT_MAX_WAIT_TIME=#{raw_value.inspect}. Using profile default (#{fallback}s)."
        fallback
      end
    rescue ArgumentError
      warnings << "[SystemTestConfig] Warning: Invalid CAPYBARA_DEFAULT_MAX_WAIT_TIME=#{raw_value.inspect}. Using profile default (#{fallback}s)."
      fallback
    end

    def resolve_retries(env, fallback, warnings)
      raw_value = env["RETRY_COUNT"]&.to_s&.strip
      return fallback unless raw_value.present?

      parsed = Integer(raw_value, 10)
      if parsed >= 0
        parsed
      else
        warnings << "[SystemTestConfig] Warning: Invalid RETRY_COUNT=#{raw_value.inspect}. Using profile default (#{fallback})."
        fallback
      end
    rescue ArgumentError
      warnings << "[SystemTestConfig] Warning: Invalid RETRY_COUNT=#{raw_value.inspect}. Using profile default (#{fallback})."
      fallback
    end
  end
end
