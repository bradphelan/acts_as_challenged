require 'rspec/mocks'

class Time
  DEFAULT_STOP_ZONE = ActiveSupport::TimeZone["UTC"]

  attr_accessor :stopped_time

  def Time.stop
    RSpec::Mocks::setup(self)
    @stopped_time = DEFAULT_STOP_ZONE.now

    # We do this to strip out the microseconds and make absolute
    # comparisons of times after saving and loading to the db
    # easier
    @stopped_time = DEFAULT_STOP_ZONE.parse(@stopped_time.to_s)

    Time.zone = DEFAULT_STOP_ZONE
    Time.zone.stub!(:now).and_return {
      @stopped_time
    }
    Time.stub!(:now).and_return {@stopped_time}
  end

  def Time.advance duration
    raise "You have not stopped time yet McFly!" unless @stopped_time
    @stopped_time = @stopped_time.since duration
  end

  def Time.regress duration
    raise "You have not stopped time yet McFly!" unless @stopped_time
    @stopped_time = @stopped_time.since -duration
  end
end

