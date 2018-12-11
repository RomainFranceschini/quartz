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

      cache = TimeCache(MySchedulable).new(TimePoint.new(5000))
      ev1 = MySchedulable.new(1)
      cache.retain_event(ev1, Scale::BASE)
      cache.advance by: Duration.new(4749)
      cache.elapsed_duration_of(ev1).should eq(Duration.new(4749))
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
    context "from a new epoch" do
      it "returns elapsed duration of an event of same precision" do
        cache = TimeCache(MySchedulable).new
        ev1 = MySchedulable.new(1)
        cache.retain_event(ev1, Scale::BASE)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0))
        cache.advance by: Duration.new(2345, Scale::BASE)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(2345))
      end

      it "returns elapsed duration of an event of a smaller precision" do
        ev1 = MySchedulable.new(1)
        tp = TimePoint.new(0, Scale::NANO)
        cache = TimeCache(MySchedulable).new(tp)
        cache.retain_event(ev1, Scale::PICO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::PICO))

        cache.advance by: Duration.new(12, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(12000, Scale::PICO))
      end

      it "returns elapsed duration of an event of a coarser precision" do
        ev1 = MySchedulable.new(1)
        tp = TimePoint.new(0, Scale::NANO)
        cache = TimeCache(MySchedulable).new(tp)
        cache.retain_event(ev1, Scale::MICRO)

        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::MICRO))

        cache.advance by: Duration.new(100, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::MICRO))

        cache.advance by: Duration.new(900, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(1, Scale::MICRO))
      end
    end

    context "within an epoch" do
      it "returns elapsed duration of an event of same precision" do
        tp = TimePoint.new(50234, Scale::BASE)
        cache = TimeCache(MySchedulable).new(tp)
        ev1 = MySchedulable.new(1)
        cache.retain_event(ev1, Scale::BASE)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0))
        cache.advance by: Duration.new(2345, Scale::BASE)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(2345))
      end

      it "returns elapsed duration of an event of a smaller precision" do
        ev1 = MySchedulable.new(1)
        tp = TimePoint.new(50234, Scale::NANO)

        cache = TimeCache(MySchedulable).new(tp)
        cache.retain_event(ev1, Scale::PICO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::PICO))

        cache.advance by: Duration.new(12, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(12000, Scale::PICO))
      end

      it "returns elapsed duration of an event of a coarser precision" do
        ev1 = MySchedulable.new(1)
        tp = TimePoint.new(5234, Scale::NANO)

        cache = TimeCache(MySchedulable).new(tp)
        cache.retain_event(ev1, Scale::MICRO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::MICRO))

        cache.advance by: Duration.new(700, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::MICRO))

        cache.advance by: Duration.new(66, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(1, Scale::MICRO))
      end
    end

    context "with overlapping epochs" do
      it "returns elapsed duration of an event of same precision" do
        tp = TimePoint.new(Duration::MULTIPLIER_MAX, Scale::BASE)
        cache = TimeCache(MySchedulable).new(tp)
        ev1 = MySchedulable.new(1)

        cache.retain_event(ev1, Scale::BASE)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0))

        cache.advance by: Duration.new(2345, Scale::BASE)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(2345))
      end

      it "returns elapsed duration of an event of a smaller precision" do
        ev1 = MySchedulable.new(1)
        tp = TimePoint.new(Duration::MULTIPLIER_MAX, Scale::NANO)
        cache = TimeCache(MySchedulable).new(tp)

        cache.retain_event(ev1, Scale::FEMTO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::FEMTO))

        cache.advance by: Duration.new(12, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(12_000_000, Scale::FEMTO))
      end

      it "returns elapsed duration of an event of a coarser precision" do
        ev1 = MySchedulable.new(1)
        tp = TimePoint.new(Duration::MULTIPLIER_MAX, Scale::NANO)

        cache = TimeCache(MySchedulable).new(tp)
        cache.retain_event(ev1, Scale::MICRO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(0, Scale::MICRO))

        cache.advance by: Duration.new(1, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(1, Scale::MICRO))

        cache.advance by: Duration.new(499, Scale::NANO)
        cache.elapsed_duration_of(ev1).should eq(Duration.new(1, Scale::MICRO))
      end
    end
  end
end
