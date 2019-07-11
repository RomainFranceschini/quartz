require "../spec_helper"

private module TerminationScenario
  class M1 < Quartz::AtomicModel
    getter time : Float64 = 0.0
    getter int_calls = 0

    def external_transition(bag)
    end

    def confluent_transition(bag)
    end

    def output
    end

    def internal_transition
      @int_calls += 1
      @time += time_advance.to_f
    end

    def time_advance
      Duration.new(100, Scale::BASE)
    end
  end

  describe "PDEVS simulation" do
    it "simulate up to given duration" do
      m = M1.new :m

      sim = Quartz::Simulation.new(m, loggers: Loggers.new(false), duration: Duration.new(10, Scale::KILO))
      sim.simulate

      m.time.should eq(Duration.new(10, Scale::KILO).to_f)
      m.int_calls.should eq(100)
    end

    it "simulate up to given time point" do
      m = M1.new :m

      sim = Quartz::Simulation.new(m, loggers: Loggers.new(false), duration: TimePoint.new(10_000, Scale::BASE))
      sim.simulate

      m.int_calls.should eq(100)
      m.time.should eq(Duration.new(10, Scale::KILO).to_f)
    end

    it "simulate up to a given termination condition" do
      m = M1.new :m
      sim = Quartz::Simulation.new(m, loggers: Loggers.new(false))
      sim.termination_condition do |vtime, root|
        m.int_calls == 100
      end
      sim.simulate
      m.int_calls.should eq(100)
      m.time.should eq(Duration.new(10, Scale::KILO).to_f)
    end
  end
end
