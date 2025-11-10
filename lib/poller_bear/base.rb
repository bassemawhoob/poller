module PollerBear
  class TimeoutError < StandardError; end

  class MaxRetriesExceededError < StandardError; end

  class Base
    attr_reader :interval, :end_time, :max_retries, :stop_when, :retry_on_exceptions

    # @param [Hash] options
    # @option options [Float, Symbol] :every The interval in seconds between each poll
    #   or +:exponential+ for exponential backoff (default: 1.0)
    # @option options [Float] :for The total duration in seconds to poll for (default: nil, meaning no
    #   time limit)
    # @option options [Integer] :max_retries The maximum number of retries on failure (default: nil,
    #   meaning unlimited)
    # @option options [Proc] :stop_when A lambda that takes the result and attempt number,
    #   and returns true to stop polling (default: true, meaning stop after the first attempt if no errors)
    # @option options [Boolean, Array<StandardError>] :retry_on_exceptions Whether to retry on exceptions
    #   raised in the block.
    def initialize(**options)
      @interval = options.fetch(:every, 1.0).then { |val| val.respond_to?(:to_f) ? val.to_f : val }
      @end_time = options.fetch(:for, nil)&.then { |duration| Time.now + duration.to_f }
      @max_retries = options.fetch(:max_retries, nil)
      @stop_when = options.fetch(:stop_when, -> (_result, _attempt) { true })
      @retry_on_exceptions = options.fetch(:retry_on_exceptions, false)

      warn_on_infinite_polling if @end_time.nil? && options[:stop_when].nil?
    end

    def poll(&)
      raise ArgumentError, "A block must be provided to poll" unless block_given?
      attempts = max_retries ? max_retries : Float::INFINITY
      error = nil

      1.upto(attempts) do |attempt|
        if end_time && Time.now >= end_time
          raise TimeoutError.new("Polling timed out"), cause: error
        end

        result = yield(attempt)
        return result if stop_when && stop_when.call(result, attempt)

        sleep_interval(attempt)
      rescue StandardError => error
        if should_retry_on_exception?(error)
          sleep_interval(attempt)
          next
        else
          raise error
        end
      end

      raise MaxRetriesExceededError.new("Polled maximum number of retries"), cause: error
    end

    private

    def warn_on_infinite_polling
      warn <<~STRING
        [PollerBear] Warning: Polling with no time limit and no stop condition will lead to infinite loops.
      STRING
    end

    def sleep_interval(attempt)
      sleep_duration = if interval.is_a?(Proc)
        interval.call(attempt)
      elsif interval == :exponential
        0.5 * (2 ** (attempt - 1))
      else
        interval
      end
      sleep(sleep_duration)
    end

    def should_retry_on_exception?(exception)
      return false unless retry_on_exceptions

      if retry_on_exceptions == true
        true
      elsif retry_on_exceptions.is_a?(Array)
        retry_on_exceptions.any? { |ex_class| exception.is_a?(ex_class) }
      else
        false
      end
    end
  end
end