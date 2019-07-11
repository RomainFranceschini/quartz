require "../spec_helper"

private module NegativeInitialTimeScenario
  class TestInitialElapsed < Quartz::AtomicModel
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0
    getter generated : Bool = false
    getter elapsed_values : Array(Duration) = Array(Duration).new

    # Set the initial elapsed time to 4 so that initial time may be negative
    @elapsed = Duration.new(4)

    def external_transition(bag)
    end

    def time_advance
      @generated ? Duration::INFINITY : Duration.new(2)
    end

    def output
      @output_calls += 1
    end

    def internal_transition
      @generated = true
      @internal_calls += 1
      @elapsed_values << @elapsed
    end
  end

  describe TestInitialElapsed do
    describe "simulation" do
      it "time might be negative at initialization" do
        atom = TestInitialElapsed.new(:testneg)
        sim = Quartz::Simulation.new(atom, duration: Quartz::Duration::INFINITY, loggers: Loggers.new(false))

        sim.initialize_simulation
        atom.time_advance.should eq(Duration.new(2))
        atom.output_calls.should eq(0)
        atom.internal_calls.should eq(0)
        atom.generated.should be_false
        atom.elapsed_values.empty?.should be_true

        sim.step

        atom.output_calls.should eq(1)
        atom.internal_calls.should eq(1)
        atom.generated.should be_true
        atom.time_advance.should eq(Quartz::Duration::INFINITY)
        atom.elapsed_values.first.should eq(Duration.new(0))
      end
    end
  end
end
