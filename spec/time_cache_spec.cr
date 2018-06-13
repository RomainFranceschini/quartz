require "./spec_helper"
require "./event_set_helper"

describe "TimeCache" do
  describe "#advance" do
    it "advance current time removes obsolete events" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      ev2 = MySchedulable.new(2)

      cache.retain_event(ev1, Scale::BASE)
      cache.advance by: Duration.new(499999999999999, Scale::BASE)
      cache.retain_event(ev2, Scale::BASE)
      cache.size.should eq(2)

      cache.advance by: Duration.new(500000000000000)
      cache.size.should eq(1)
      cache.advance by: Duration.new(Duration::MULTIPLIER_MAX, Scale::BASE)
      cache.size.should eq(0)
    end
  end

  describe "#release_event" do
    it "cancels previously retained events" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      cache.retain_event(ev1, Scale::BASE)
      cache.size.should eq(1)
      cache.release_event(ev1).should eq(ev1)
      cache.size.should eq(0)

      cache.advance by: Duration.new(1234)
      cache.retain_event(ev1, Scale::BASE)
      cache.advance by: Duration.new(762534)
      cache.size.should eq(1)
      cache.release_event(ev1).should eq(ev1)
      cache.size.should eq(0)
    end
  end

  describe "#retain_event" do
    it "tracks events relative to the current time" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      cache.size.should eq(0)
      cache.retain_event(ev1, Scale::BASE)
      cache.@time_queue.duration_of(ev1).should eq(Duration.new(Duration::MULTIPLIER_MAX, Scale::BASE))
      cache.advance by: Duration.new(234)
      cache.size.should eq(1)
      cache.@time_queue.duration_of(ev1).should eq(Duration.new(Duration::MULTIPLIER_MAX - 234, Scale::BASE))
    end

    it "may be given an initial elapsed duration" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      cache.size.should eq(0)
      cache.retain_event(ev1, Duration.new(50, Scale::BASE))
      cache.@time_queue.duration_of(ev1).should eq(Duration.new(Duration::MULTIPLIER_MAX - 50, Scale::BASE))
      cache.advance by: Duration.new(234)
      cache.size.should eq(1)
      cache.@time_queue.duration_of(ev1).should eq(Duration.new(Duration::MULTIPLIER_MAX - 234 - 50, Scale::BASE))
    end
  end

  describe "#elapsed_duration_of" do
    pending "returns elapsed duration associated with a retained event" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      cache.retain_event(ev1, Scale::BASE)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(0))
      cache.advance by: Duration.new(2345, Scale::BASE)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(2345))

      tp = TimePoint.new(50234, Scale::BASE)
      cache = TimeCache(MySchedulable).new(tp)
      ev1 = MySchedulable.new(1)
      cache.retain_event(ev1, Scale::BASE)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(0))
      cache.advance by: Duration.new(2345, Scale::BASE)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(2345))

      tp = TimePoint.new(Duration::MULTIPLIER_MAX, Scale::NANO)
      cache = TimeCache(MySchedulable).new(tp)
      cache.retain_event(ev1, Scale::FEMTO)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::FEMTO))
      cache.advance by: Duration.new(12, Scale::NANO)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(13000, Scale::FEMTO))
    end
  end
end
