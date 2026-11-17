require "application_system_test_case"
require "stringio"

class SystemTestConfigTest < ActiveSupport::TestCase
  TRACKED_ENV_KEYS = %w[
    CI
    TEST_PROFILE
    CAPYBARA_DEFAULT_MAX_WAIT_TIME
    RETRY_COUNT
  ].freeze

  setup do
    @saved_env = TRACKED_ENV_KEYS.index_with { |key| ENV[key] }
    @saved_wait_time = Capybara.default_max_wait_time
    @saved_retry_count = Minitest::Retry.retry_count
    @saved_retry_io = Minitest::Retry.io
    @saved_retry_verbose = Minitest::Retry.verbose
    @saved_retry_exceptions = Minitest::Retry.exceptions_to_retry
  end

  teardown do
    @saved_env.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end

    SystemTestConfig.apply!(env: ENV, io: StringIO.new)
    Capybara.default_max_wait_time = @saved_wait_time
    Minitest::Retry.use!(
      retry_count: @saved_retry_count,
      io: @saved_retry_io || $stdout,
      verbose: @saved_retry_verbose != false,
      exceptions_to_retry: @saved_retry_exceptions || SystemTestConfig::DEFAULT_RETRY_EXCEPTIONS,
    )
  end

  test "defaults to FAST profile locally when CI and TEST_PROFILE are unset" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(env: {})

      assert_equal "FAST", config.profile
      assert config.fast?
      refute config.robust?
      assert_equal 2, config.wait_time
      assert_equal 0, config.retries
      assert_empty config.warnings
    end

    assert_equal 2, Capybara.default_max_wait_time
    assert_equal 0, Minitest::Retry.retry_count
    assert_includes out, "Active Test Profile: FAST (Wait: 2s, Retries: 0)"
    assert_equal "", err
  end

  test "enforces ROBUST profile automatically when ENV['CI'] is present" do
    %w[true 1 github_actions].each do |ci_value|
      out, err = capture_io do
        config = SystemTestConfig.apply!(env: {"CI" => ci_value})

        assert_equal "ROBUST", config.profile
        assert config.robust?
        refute config.fast?
        assert_equal 15, config.wait_time
        assert_equal 6, config.retries
        assert_empty config.warnings
      end

      assert_equal 15, Capybara.default_max_wait_time
      assert_equal 6, Minitest::Retry.retry_count
      assert_equal true, Minitest::Retry.verbose
      assert_equal [Net::ReadTimeout, Capybara::ModalNotFound], Minitest::Retry.exceptions_to_retry
      assert_includes out, "Active Test Profile: ROBUST (Wait: 15s, Retries: 6)"
      assert_equal "", err
    end
  end

  test "supports explicit runtime override via TEST_PROFILE=ROBUST locally" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(env: {"TEST_PROFILE" => "ROBUST"})

      assert_equal "ROBUST", config.profile
      assert_equal 15, config.wait_time
      assert_equal 6, config.retries
    end

    assert_equal 15, Capybara.default_max_wait_time
    assert_equal 6, Minitest::Retry.retry_count
    assert_includes out, "Active Test Profile: ROBUST (Wait: 15s, Retries: 6)"
    assert_equal "", err
  end

  test "supports case-insensitive TEST_PROFILE=fast override" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(env: {"CI" => "true", "TEST_PROFILE" => " fast "})

      assert_equal "FAST", config.profile
      assert_equal 2, config.wait_time
      assert_equal 0, config.retries
    end

    assert_equal 2, Capybara.default_max_wait_time
    assert_equal 0, Minitest::Retry.retry_count
    assert_includes out, "Active Test Profile: FAST (Wait: 2s, Retries: 0)"
    assert_equal "", err
  end

  test "logs a warning and safely falls back to ROBUST on invalid TEST_PROFILE" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(env: {"TEST_PROFILE" => "TURBO"})

      assert_equal "ROBUST", config.profile
      assert_equal 15, config.wait_time
      assert_equal 6, config.retries
      assert_equal 1, config.warnings.size
    end

    assert_equal 15, Capybara.default_max_wait_time
    assert_equal 6, Minitest::Retry.retry_count
    assert_match(/Warning:.*TURBO.*Falling back to ROBUST/i, err)
    assert_includes out, "Active Test Profile: ROBUST (Wait: 15s, Retries: 6)"
  end

  test "respects explicit CAPYBARA_DEFAULT_MAX_WAIT_TIME and RETRY_COUNT overrides" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(
        env: {
          "CAPYBARA_DEFAULT_MAX_WAIT_TIME" => "8",
          "RETRY_COUNT" => "3",
        }
      )

      assert_equal "FAST", config.profile
      assert_equal 8, config.wait_time
      assert_equal 3, config.retries
    end

    assert_equal 8, Capybara.default_max_wait_time
    assert_equal 3, Minitest::Retry.retry_count
    assert_includes out, "Active Test Profile: FAST (Wait: 8s, Retries: 3)"
    assert_equal "", err
  end

  test "supports zero RETRY_COUNT and float CAPYBARA_DEFAULT_MAX_WAIT_TIME overrides over ROBUST" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(
        env: {
          "CI" => "1",
          "CAPYBARA_DEFAULT_MAX_WAIT_TIME" => "4.5",
          "RETRY_COUNT" => "0",
        }
      )

      assert_equal "ROBUST", config.profile
      assert_equal 4.5, config.wait_time
      assert_equal 0, config.retries
    end

    assert_equal 4.5, Capybara.default_max_wait_time
    assert_equal 0, Minitest::Retry.retry_count
    assert_includes out, "Active Test Profile: ROBUST (Wait: 4.5s, Retries: 0)"
    assert_equal "", err
  end

  test "falls back to profile defaults with warning when numeric overrides are malformed" do
    out, err = capture_io do
      config = SystemTestConfig.apply!(
        env: {
          "CAPYBARA_DEFAULT_MAX_WAIT_TIME" => "not_a_number",
          "RETRY_COUNT" => "-2",
        }
      )

      assert_equal "FAST", config.profile
      assert_equal 2, config.wait_time
      assert_equal 0, config.retries
      assert_equal 2, config.warnings.size
    end

    assert_match(/Invalid CAPYBARA_DEFAULT_MAX_WAIT_TIME/i, err)
    assert_match(/Invalid RETRY_COUNT/i, err)
    assert_includes out, "Active Test Profile: FAST (Wait: 2s, Retries: 0)"
  end

  test "prints formatted startup banner to custom io stream" do
    buffer = StringIO.new
    SystemTestConfig.apply!(env: {"TEST_PROFILE" => "FAST"}, io: buffer)

    lines = buffer.string.lines.map(&:chomp)
    assert_equal 3, lines.size
    assert_equal SystemTestConfig::BANNER_DIVIDER, lines[0]
    assert_equal "Active Test Profile: FAST (Wait: 2s, Retries: 0)", lines[1]
    assert_equal SystemTestConfig::BANNER_DIVIDER, lines[2]
  end

  test "test macro with stability: :high_friction elevates Capybara wait time to 15s and restores after test" do
    SystemTestConfig.apply!(env: {}, io: StringIO.new)
    assert_equal 2, Capybara.default_max_wait_time

    observed_standard_wait = nil
    observed_high_friction_wait = nil
    observed_inline_override_wait = nil

    with_ephemeral_system_test_case do |klass|
      klass.test "standard fast test" do
        observed_standard_wait = Capybara.default_max_wait_time
      end

      klass.test "complex webhook flow", stability: :high_friction do
        observed_high_friction_wait = Capybara.default_max_wait_time
        Capybara.using_wait_time(5) do
          observed_inline_override_wait = Capybara.default_max_wait_time
        end
      end

      instance_fast = klass.new("test_standard_fast_test")
      instance_fast.test_standard_fast_test

      instance_slow = klass.new("test_complex_webhook_flow")
      instance_slow.test_complex_webhook_flow
    end

    assert_equal 2, observed_standard_wait
    assert_equal 15, observed_high_friction_wait
    assert_equal 5, observed_inline_override_wait
    assert_equal 2, Capybara.default_max_wait_time
  end

  test "class-level stability :high_friction elevates wait time for tests in the group" do
    SystemTestConfig.apply!(env: {}, io: StringIO.new)
    observed_wait = nil

    with_ephemeral_system_test_case do |klass|
      klass.stability :high_friction
      klass.test "group tagged complex test" do
        observed_wait = Capybara.default_max_wait_time
      end

      klass.new("test_group_tagged_complex_test").test_group_tagged_complex_test
    end

    assert_equal 15, observed_wait
    assert_equal 2, Capybara.default_max_wait_time
  end

  test "device_test macro supports stability: :high_friction" do
    SystemTestConfig.apply!(env: {}, io: StringIO.new)
    observed_wait = nil

    with_ephemeral_system_test_case do |klass|
      klass.define_method(:resize_display) { |*_| }
      klass.device_test "device tagged flow", stability: :high_friction do
        observed_wait = Capybara.default_max_wait_time
      end

      method_name = klass.instance_methods(false).find { |m| m.to_s.start_with?("test_device_tagged_flow") }
      assert method_name, "Expected device_test to define a test method"
      klass.new(method_name.to_s).public_send(method_name)
    end

    assert_equal 15, observed_wait
    assert_equal 2, Capybara.default_max_wait_time
  end

  test "high_friction instance helper elevates wait time inline and restores even on error" do
    SystemTestConfig.apply!(env: {}, io: StringIO.new)
    assert_equal 2, Capybara.default_max_wait_time

    observed_inside_block = nil

    with_ephemeral_system_test_case do |klass|
      instance = klass.new("test_inline")

      return_value = instance.high_friction do
        observed_inside_block = Capybara.default_max_wait_time
        :completed
      end

      assert_equal :completed, return_value
      assert_equal 15, observed_inside_block
      assert_equal 2, Capybara.default_max_wait_time

      assert_raises(RuntimeError) do
        instance.high_friction do
          assert_equal 15, Capybara.default_max_wait_time
          raise "simulated failure"
        end
      end

      assert_equal 2, Capybara.default_max_wait_time
    end
  end

  test "high_friction preserves higher explicit CAPYBARA_DEFAULT_MAX_WAIT_TIME override" do
    SystemTestConfig.apply!(
      env: {"CAPYBARA_DEFAULT_MAX_WAIT_TIME" => "25"},
      io: StringIO.new,
    )
    assert_equal 25, Capybara.default_max_wait_time

    observed_wait = nil

    with_ephemeral_system_test_case do |klass|
      instance = klass.new("test_higher_override")
      instance.high_friction do
        observed_wait = Capybara.default_max_wait_time
      end
    end

    assert_equal 25, observed_wait
    assert_equal 25, Capybara.default_max_wait_time
  end

  private

  def with_ephemeral_system_test_case
    klass = Class.new(ApplicationSystemTestCase)
    yield klass
  ensure
    Minitest::Runnable.runnables.delete(klass) if klass
  end
end
