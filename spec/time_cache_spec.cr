require "./spec_helper"
require "./event_set_helper"

describe "TimeCache" do
  describe "#retain_event" do
    it "tracks events relative to the current time" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      cache.retain_event(ev1, Scale::BASE)
      ev1.imaginary_phase.should eq(Duration.new(Duration::MULTIPLIER_MAX, Scale::BASE))
      cache.elapsed_duration_of(ev1).should eq(Duration.new(0))

      cache.advance by: Duration.new(234)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(234))

      ev2 = MySchedulable.new(2)
      cache.retain_event(ev2, Scale::BASE)

      ev2.imaginary_phase.should eq(Duration.new(233, Scale::BASE))
      cache.elapsed_duration_of(ev2).should eq(Duration.new(0))
    end

    it "may be given an initial elapsed duration" do
      cache = TimeCache(MySchedulable).new
      ev1 = MySchedulable.new(1)
      cache.retain_event(ev1, Duration.new(50, Scale::BASE))
      ev1.imaginary_phase.should eq(Duration.new(Duration::MULTIPLIER_MAX - 50, Scale::BASE))
      cache.advance by: Duration.new(234)
      ev1.imaginary_phase.should eq(Duration.new(Duration::MULTIPLIER_MAX - 234 - 50 + 234, Scale::BASE))
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
