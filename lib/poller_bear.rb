require "poller_bear/version"
require "poller_bear/base"

module PollerBear
  def self.poll(**options, &)
    PollerBear::Base.new(**options).poll(&)
  end
end
