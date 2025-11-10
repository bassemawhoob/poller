require "test_helper"

class PollerBearTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::PollerBear::VERSION
  end

  def test_returns_result_of_block
    result = PollerBear.poll(every: 0.01, for: 0.01) do
      :desired_result
    end
    assert_equal :desired_result, result
  end

  def test_poll_stops_when_condition_met
    attempt_counts = []
    result = PollerBear.poll(every: 0.01, stop_when: -> (_, attempt) { attempt >= 3 }) do |attempt|
      attempt_counts << attempt
      :some_result
    end
    assert_equal :some_result, result
    assert_equal [1, 2, 3], attempt_counts
  end

  def test_poll_stops_after_duration
    attempt_counts = []
    assert_raises(PollerBear::TimeoutError) do
      PollerBear.poll(every: 0.01, for: 0.05, stop_when: -> (_, _) { false }) do |attempt|
        attempt_counts << attempt
      end
    end
    assert_equal [1, 2, 3, 4, 5], attempt_counts
  end

  def test_retries_on_specified_exceptions
    attempt_counts = []
    result = PollerBear.poll(every: 0.01, stop_when: -> (_, attempt) { attempt >= 3 }, retry_on_exceptions: [RuntimeError]) do |attempt|
      attempt_counts << attempt
      raise RuntimeError, "Temporary error" if attempt < 3
      :successful_result
    end

    assert_equal :successful_result, result
    assert_equal [1, 2, 3], attempt_counts
  end

  def test_retries_on_all_exceptions
    attempt_counts = []
    result = PollerBear.poll(every: 0.01, stop_when: -> (_, attempt) { attempt >= 3 }, retry_on_exceptions: true) do |attempt|
      attempt_counts << attempt
      raise StandardError, "Temporary error" if attempt < 3
      :successful_result
    end

    assert_equal :successful_result, result
    assert_equal [1, 2, 3], attempt_counts
  end

  def test_does_not_retry_on_unlisted_exceptions
    attempt_counts = []
    assert_raises(StandardError) do
      PollerBear.poll(every: 0.01, retry_on_exceptions: [RuntimeError]) do |attempt|
        attempt_counts << attempt
        raise StandardError, "Non-retryable error"
      end
    end
    assert_equal [1], attempt_counts
  end

  def test_raises_argument_error_without_block
    assert_raises(ArgumentError) do
      PollerBear.poll(every: 0.01, for: 0.05)
    end
  end

  def test_raises_too_many_attempts_error
    attempt_counts = []
    assert_raises(PollerBear::MaxRetriesExceededError) do
      PollerBear.poll(every: 0.01, max_retries: 3, stop_when: -> (_, _) { false }) do |attempt|
        attempt_counts << attempt
      end
    end
    assert_equal [1, 2, 3], attempt_counts
  end

  def test_sleep_interval_with_exponential_symbol
    start = Time.now.utc
    times = []
    result = PollerBear.poll(every: :exponential, max_retries: 3, stop_when: -> (result, _) { result }) do |attempt|
      times << Time.now.utc
      :some_result if attempt == 3
    end
    times = times.map { |time| time - start }
    assert_equal :some_result, result
    assert_equal 3, times.size
    assert times[1] > times[0] * 2
    assert times[2] > times[1] * 2
  end

  def test_every_as_callable_returning_constant
    result = PollerBear.poll(every: -> (_) { 1 }, for: 0.1) do
      :some_result
    end
    assert_equal :some_result, result
  end

  def test_does_not_swallow_raised_exceptions
    assert_raises(ZeroDivisionError) do
      PollerBear.poll(every: 0.01, for: 0.05) do
        1 / 0
      end
    end
  end

  def test_warning_on_infinite_polling
    warning_message = capture_io { PollerBear::Base.new(every: 0.01) }.join
    assert_includes warning_message, <<~STRING
      [PollerBear] Warning: Polling with no time limit and no stop condition will lead to infinite loops.
    STRING
  end
end