require "./spec_helper"
require "./event_set_helper"

describe "EventSet" do
  describe "#size" do
    it "returns the number of planned events" do
      pes = EventSet(MySchedulable).new
      pes.plan_event(MySchedulable.new(1), Duration.new(1))
      pes.plan_event(MySchedulable.new(2), Duration.new(1))
      pes.plan_event(MySchedulable.new(3), Duration.new(3))
      pes.plan_event(MySchedulable.new(4), Duration.new(8))
      pes.size.should eq 4
    end
  end

  describe "#empty?" do
    it "indicates whether the event set is empty" do
      pes = EventSet(MySchedulable).new
      pes.empty?.should be_true

      pes.plan_event(MySchedulable.new(1), Duration.new(1))
      pes.plan_event(MySchedulable.new(2), Duration.new(1))
      pes.plan_event(MySchedulable.new(3), Duration.new(3))
      pes.plan_event(MySchedulable.new(4), Duration.new(8))
      pes.empty?.should be_false

      pes.pop_imminent_events
      pes.pop_imminent_events
      pes.pop_imminent_events
      pes.empty?.should be_true
    end
  end

  describe "#cmp_planned_phases" do
    it "compares two planned phases" do
      pes = EventSet(MySchedulable).new
      pes.cmp_planned_phases(Duration.new(1), Duration.new(2)).should eq(-1)
      pes.cmp_planned_phases(Duration.new(2), Duration.new(1)).should eq(1)
      pes.cmp_planned_phases(Duration.new(2), Duration.new(2)).should eq(0)
      pes.cmp_planned_phases(Duration.new(15434, Scale::MILLI), Duration.new(17)).should eq(-1)
      pes.cmp_planned_phases(Duration.new(5), Duration.new(5000, Scale::MILLI)).should eq(0)

      ct = 87_234
      pes = EventSet(MySchedulable).new(TimePoint.new(ct))
      pes.cmp_planned_phases(Duration.new(ct + 1), Duration.new(ct + 2)).should eq(-1)
      pes.cmp_planned_phases(Duration.new(ct + 2), Duration.new(ct + 1)).should eq(1)
      pes.cmp_planned_phases(Duration.new(ct + 2), Duration.new(ct + 2)).should eq(0)
      pes.cmp_planned_phases(Duration.new(ct*1000 + 15434, Scale::MILLI), Duration.new(ct + 17)).should eq(-1)
      pes.cmp_planned_phases(Duration.new(ct + 5), Duration.new(ct*1000 + 5000, Scale::MILLI)).should eq(0)
    end
  end

  describe "#refined_duration" do
    it "refines a duration using according to multiscale advancement rules" do
      pes = EventSet(MySchedulable).new
      pes.refined_duration(Duration.new(5, Scale::KILO), Scale::BASE).should eq(Duration.new(5000))

      pes.advance by: Duration.new(435_234_112_982_993)
      duration = Duration.new(100_000_000_000_003)
      pes.refined_duration(duration, Scale::BASE).should eq(Duration.new(100_000_000_000_003))
      pes.refined_duration(duration.rescale(Scale::KILO), Scale::BASE).should eq(Duration.new(99_999_999_999_007))
      pes.refined_duration(duration.rescale(Scale::MEGA), Scale::BASE).should eq(Duration.new(99_999_999_017_007))
      pes.refined_duration(duration.rescale(Scale::GIGA), Scale::BASE).should eq(Duration.new(99_999_887_017_007))
      pes.refined_duration(duration.rescale(Scale::TERA), Scale::BASE).should eq(Duration.new(99_765_887_017_007))
    end
  end

  describe "conversion" do
    describe "from duration to phase" do
      it "returns the same duration when current time matches a new epoch" do
        # first epoch
        pes = EventSet(MySchedulable).new
        planned_duration = Duration.new(500)
        planned_phase = pes.phase_from_duration(planned_duration)
        planned_phase.should eq(planned_duration)

        # second epoch
        pes = EventSet(MySchedulable).new(TimePoint.new(Duration::MULTIPLIER_LIMIT))
        planned_phase = pes.phase_from_duration(planned_duration)
        planned_phase.should eq(planned_duration)
      end

      it "always returns a shorter duration for phases in the next epoch" do
        tp = TimePoint.new(Duration::MULTIPLIER_LIMIT - 1500)
        pes = EventSet(MySchedulable).new(tp)
        planned_duration = Duration.new(5000)
        planned_phase = pes.phase_from_duration(planned_duration)
        (planned_phase < planned_duration).should be_true
        planned_phase.should eq(Duration.new(3500))

        tp = TimePoint.new(Duration::MULTIPLIER_LIMIT - 2000)
        pes = EventSet(MySchedulable).new(tp)
        planned_duration = Duration.new(6020)
        planned_phase = pes.phase_from_duration(planned_duration)
        (planned_phase < planned_duration).should be_true
        planned_phase.should eq(Duration.new(4020))
      end

      it "coarsens precision as long as no accuracy is lost" do
        # current phase, coarsened result
        pes = EventSet(MySchedulable).new(TimePoint.new(2000))
        planned_duration = Duration.new(5_000_000, Scale::MILLI)
        planned_phase = pes.phase_from_duration(planned_duration)
        (planned_phase > planned_duration).should be_true
        planned_phase.should eq(Duration.new(7, Scale::KILO))

        # next phase, coarsened result
        tp = TimePoint.new(Duration::MULTIPLIER_LIMIT - 2000)
        pes = EventSet(MySchedulable).new(tp)
        planned_duration = Duration.new(5000)
        planned_phase = pes.phase_from_duration(planned_duration)
        planned_phase.should eq(Duration.new(3, Scale::KILO))
        (planned_phase < planned_duration).should be_true
      end

      it "coarses phase to default precision (0) when current time is 0" do
        pes = EventSet(MySchedulable).new(TimePoint.new(0, Scale::MILLI))
        pes.phase_from_duration(Duration.new(134)).precision.should eq(Scale::BASE)
      end

      it "current time precision is used for durations of zero" do
        pes = EventSet(MySchedulable).new(TimePoint.new(23457, Scale::MICRO))
        pes.phase_from_duration(Duration.new(0, Scale::TERA)).precision.should eq(Scale::MICRO)
      end
    end

    describe "from phase to duration" do
      it "returns the same duration when the current time is a new epoch" do
        pes = EventSet(MySchedulable).new
        duration = pes.duration_from_phase(Duration.new(500))
        duration.should eq(Duration.new(500))

        pes = EventSet(MySchedulable).new(TimePoint.new(Duration::MULTIPLIER_LIMIT))
        duration = pes.duration_from_phase(Duration.new(500))
        duration.should eq(Duration.new(500))
      end

      it "returns a duration relative to the current time" do
        planned_phase = Duration.new(69234)
        pes = EventSet(MySchedulable).new(TimePoint.new(5))
        pes.duration_from_phase(planned_phase).should eq(Duration.new(69234 - 5))

        pes = EventSet(MySchedulable).new(TimePoint.new(898))
        pes.duration_from_phase(planned_phase).should eq(Duration.new(69234 - 898))

        planned_phase = Duration.new(1000)
        pes = EventSet(MySchedulable).new(TimePoint.new(999))
        pes.duration_from_phase(planned_phase).should eq(Duration.new(1000 - 999))
      end
    end

    describe "to epoch phase" do
      it "is always < MULTIPLIER_LIMIT" do
        t = TimePoint.new(999, 999, 999, 999, 999, precision: Scale::BASE)
        pes = EventSet(MySchedulable).new(t)
        pes.epoch_phase(Scale::BASE).should eq(Duration::MULTIPLIER_MAX)

        t = TimePoint.new(999, 999, 999, 999, 999, 999, precision: Scale::BASE)
        pes = EventSet(MySchedulable).new(t)
        pes.epoch_phase(Scale::BASE).should eq(Duration::MULTIPLIER_MAX)
      end

      it "is always > 0" do
        pes = EventSet(MySchedulable).new
        pes.epoch_phase(Scale::BASE).should eq(0)

        t = TimePoint.new(999, 999, 999, 999, 999, 999, precision: Scale::BASE)
        pes = EventSet(MySchedulable).new(t)
        pes.epoch_phase(Scale::FEMTO).should eq(0)
      end
    end
  end

  describe "#duration_of" do
    it "returns the duration after which the specified event will occur relative to the current time" do
      pes = EventSet(MySchedulable).new
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(6889))

      pes.duration_of(ev).should eq(Duration.new(6889))

      pes.advance by: Duration.new(1234)
      pes.duration_of(ev).should eq(Duration.new(6889 - 1234))

      pes.advance
      pes.duration_of(ev).should eq(Duration.new(0))
    end

    it "returns a planned duration matching the original precision" do
      pes = EventSet(MySchedulable).new
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(1000))

      pes.duration_of(ev).should eq(Duration.new(1000))
      pes.duration_of(ev).precision.should eq(Scale.new(0))

      pes.advance by: Duration.new(999)
    end

    it "avoid rounding errors" do
      pes = EventSet(MySchedulable).new
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(1000))
      pes.advance by: Duration.new(999)

      pes.duration_of(ev).should eq(Duration.new(1))
      pes.duration_of(ev).precision.should eq(Scale.new(0))
    end

    it "handles events scheduled for the next epoch" do
      pes = EventSet(MySchedulable).new
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT - 6500)
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(10_234))

      pes.duration_of(ev).should eq(Duration.new(10_234))

      pes.advance by: Duration.new(1234)
      pes.duration_of(ev).should eq(Duration.new(10_234 - 1234))

      pes.advance
      pes.duration_of(ev).should eq(Duration.new(0))
    end
  end

  describe "#advance" do
    describe "with no arguments" do
      it "increase current time up to the imminent events" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(1))
        pes.plan_event(MySchedulable.new(2), Duration.new(5))

        pes.current_time.should eq(TimePoint.new(0))
        pes.imminent_duration.should eq(Duration.new(1))

        pes.advance
        pes.current_time.should eq(TimePoint.new(1))
        pes.imminent_duration.should eq(Duration.new(0))
        pes.pop_imminent_events
        pes.imminent_duration.should eq(Duration.new(4))

        pes.advance
        pes.current_time.should eq(TimePoint.new(5))
        pes.imminent_duration.should eq(Duration.new(0))
        pes.pop_imminent_events
      end
    end

    describe "given a duration" do
      it "raises if it exceed imminent duration" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(3))

        pes.current_time.should eq(TimePoint.new(0))
        pes.imminent_duration.should eq(Duration.new(3))
        expect_raises(Exception, "Current time cannot advance beyond imminent events.") do
          pes.advance by: Duration.new(3001, precision: Scale.new(-1))
        end
      end

      it "applies multiscale advancement" do
        pes = EventSet(MySchedulable).new(TimePoint.new(500111, Scale::FEMTO))
        pes.advance by: Duration.new(300, Scale::PICO)
        pes.current_time.should eq(TimePoint.new(800, Scale::PICO))
      end
    end

    describe "given a time point" do
      it "increase current time up to given time point" do
        pes = EventSet(MySchedulable).new(TimePoint.new(5, Scale::PICO))
        pes.advance until: TimePoint.new(982734, Scale::MILLI)
        pes.current_time.should eq(TimePoint.new(982734, Scale::MILLI))
      end

      it "raises if it exceed imminent duration" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(3))

        pes.current_time.should eq(TimePoint.new(0))
        pes.imminent_duration.should eq(Duration.new(3))

        expect_raises(Exception, "Current time cannot advance beyond imminent events.") do
          pes.advance until: TimePoint.new(3001, precision: Scale.new(-1))
        end
      end
    end

    describe "#imminent_duration" do
      it "returns due duration before the next planned event(s) occur" do
        pes = EventSet(MySchedulable).new
        pes.imminent_duration.should eq(Duration::INFINITY)

        pes.plan_event(MySchedulable.new(1), Duration.new(1234, Scale::MICRO))
        pes.imminent_duration.should eq(Duration.new(1234, Scale::MICRO))

        pes.advance by: Duration.new(1, Scale::MILLI)
        pes.imminent_duration.should eq(Duration.new(234, Scale::MICRO))

        pes.advance by: Duration.new(234, Scale::MICRO)
        pes.imminent_duration.should eq(Duration.new(0, Scale::MICRO))
      end

      it "handles passage from an epoch to another" do
        pes = EventSet(MySchedulable).new
        pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT - 6500)

        pes.plan_event(MySchedulable.new(1), Duration.new(4358))
        pes.plan_event(MySchedulable.new(2), Duration.new(6500))
        pes.plan_event(MySchedulable.new(3), Duration.new(7634))

        pes.@priority_queue.size.should eq(1)
        pes.@future_events.size.should eq(2)

        pes.imminent_duration.should eq(Duration.new(4358))
        pes.advance by: Duration.new(1500)
        pes.imminent_duration.should eq(Duration.new(4358 - 1500))
        pes.pop_imminent_event.should eq(1)

        pes.imminent_duration.should eq(Duration.new(6500 - 1500))
        pes.advance
        pes.imminent_duration.should eq(Duration.new(0))
        pes.pop_imminent_event.should eq(2)

        pes.imminent_duration.should eq(Duration.new(1134))
      end

      it "returns a planned duration matching current time precision" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(1000))
        pes.imminent_duration.should eq(Duration.new(1000))
        pes.imminent_duration.precision.should eq(Scale.new(0))

        pes.advance by: Duration.new(999)
        pes.imminent_duration.should eq(Duration.new(1))
        pes.imminent_duration.precision.should eq(Scale.new(0))
      end
    end

    describe "#cancel_event" do
      it "removes and returns the specified event" do
        pes = EventSet(MySchedulable).new
        ev1 = MySchedulable.new(1)
        ev2 = MySchedulable.new(2)
        pes.plan_event(ev1, Duration.new(5))
        pes.plan_event(ev2, Duration.new(7))

        pes.imminent_duration.should eq(Duration.new(5))
        pes.size.should eq(2)
        pes.cancel_event(ev1).should eq(1)
        pes.size.should eq(1)
        pes.imminent_duration.should eq(Duration.new(7))

        pes.cancel_event(ev2).should eq(2)
        pes.empty?.should be_true
      end

      it "removes and returns events occuring in the next epoch" do
        pes = EventSet(MySchedulable).new
        pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)
        ev = MySchedulable.new(1)
        pes.plan_event(ev, Duration.new(Duration::MULTIPLIER_MAX))

        pes.size.should eq(1)
        pes.cancel_event(ev).should eq(1)
        pes.size.should eq(0)
      end
    end

    describe "#pop_imminent_event" do
      it "deletes and returns the next imminent event" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(5))
        pes.plan_event(MySchedulable.new(2), Duration.new(7))
        pes.pop_imminent_event.should eq(1)
        pes.pop_imminent_event.should eq(2)
      end
    end

    describe "#pop_imminent_events" do
      it "deletes and returns the all imminent events" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(5))
        pes.plan_event(MySchedulable.new(2), Duration.new(7))
        pes.plan_event(MySchedulable.new(3), Duration.new(7))

        pes.pop_imminent_events.should eq([1])
        imm = pes.pop_imminent_events
        imm.should contain(2)
        imm.should contain(3)
      end
    end

    describe "#plan_event" do
      it "stores in the priority queue all events occuring in the current epoch" do
        pes = EventSet(MySchedulable).new
        pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)

        pes.size.should eq(0)
        pes.plan_event(MySchedulable.new(1), Duration.new(500_234_848))
        pes.size.should eq(1)

        pes.@priority_queue.size.should eq(1)
        pes.@future_events.size.should eq(0)
      end

      it "delays storage in the priority queue of all events occuring in the next epoch" do
        pes = EventSet(MySchedulable).new
        pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)

        pes.size.should eq(0)
        pes.plan_event(MySchedulable.new(1), Duration.new(Duration::MULTIPLIER_MAX))
        pes.size.should eq(1)

        pes.@priority_queue.size.should eq(0)
        pes.@future_events.size.should eq(1)
      end
    end
  end
end
