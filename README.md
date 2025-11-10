# PollerBear

A zero-dependency Ruby gem built for effortless polling. 
Perfect for external APIs and any task that requires, repeatable retries until your conditions are met. 
Elegant and beautifully expressive.

```ruby
PollerBear.poll(every: 1, for: 15, stop_when: -> (response, attempt) { response.success? }) do
  make_api_call
end

# => { "status" => 200,  "body" => "Yay, the API finally worked!" }
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'poller_bear'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install poller_bear

## Usage

PollerBear exposes a single method poll

```ruby
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
poll(every: 1.0, for: nil, max_retries: nil, stop_when: ->(result, attempt) { true }, retry_on_exceptions: false, &block)
```

### Examples

- Polling until timeout

```ruby
PollerBear.poll(every: 1, for: 10, stop_when: ->(result, attempt) { result == :done }) do |attempt|
  puts "Polling..."
end

# => "Polling..." 
# => "Polling..." 
# .. (repeated every second for 10 seconds)
# PollerBear::TimeoutError raised
```

- Polling with maximum retries

```ruby
PollerBear.poll(every: 2, max_retries: 3, stop_when: ->(result, attempt) { result == :done }) do |attempt|
  puts "Polling..."
end

# => "Polling..."
# => "Polling..."
# => "Polling..."
# PollerBear::MaxRetriesExceededError raised
```

- Built-in exponential backoff (base: 0.5 seconds, factor: 2)

```ruby
start = Time.now
PollerBear.poll(every: :exponential, max_retries: 4, stop_when: ->(result, attempt) { result == :done }) do |attempt|
  puts Time.now - start
end
# => 0 seconds
# => 0.5 seconds
# => 1.5 seconds
# => 3.5 seconds
# PollerBear::MaxRetriesExceededError raised
```

- Custom wait time

```ruby
start = Time.now
PollerBear.poll(every: -> (attempt) { attempt + 2 }, for: 20, stop_when: ->(result, attempt) { result == :done }) do
  puts Time.now - start
end

# => 0 seconds
# => 3 seconds
# => 7 seconds
# => 12 seconds
# => 18 seconds
# PollerBear::TimeoutError raised
```

- Retry on exceptions

```ruby
PollerBear.poll(every: 1, max_retries: 5, retry_on_exceptions: true, stop_when: ->(result, attempt) { result == :done }) do |attempt|
  puts "Attempt #{attempt}"
  raise "Temporary failure" if attempt < 4
  :done
end

# => "Attempt 1"
# => "Attempt 2"
# => "Attempt 3"
# => "Attempt 4"
# => :done
```

- Retry on specific exceptions

```ruby
PollerBear.poll(every: 1, max_retries: 5, retry_on_exceptions: [RuntimeError], stop_when: ->(result, attempt) { result == :done }) do |attempt|
  puts "Attempt #{attempt}"
  raise RuntimeError, "Temporary failure" if attempt < 4
  :done
end

# => "Attempt 1"
# => "Attempt 2"
# => "Attempt 3"
# => "Attempt 4"
# => :done
```

- Passing `every` and `for` as durations (when ActiveSupport is available)

```ruby
PollerBear.poll(every: 5.seconds, for: 2.minutes, stop_when: ->(result, attempt) { result == :done }) do
  puts "Polling..."
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bassemawhoob/poller_bear.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
