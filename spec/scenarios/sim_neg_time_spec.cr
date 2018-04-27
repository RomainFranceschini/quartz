require "../spec_helper"

private module NegativeInitialTimeScenario
  class NegativeTestError < Exception; end

  class TestInitialElapsed < Quartz::AtomicModel
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0
    getter generated : Bool = false

    # Set the initial elapsed time to 4 so that initial time may be negative
    @elapsed = Duration.new(4)

    def time_advance
      @generated ? Duration::INFINITY : Duration.new(2)
    end

    def output
      @output_calls += 1
    end

    def internal_transition
      @generated = true
      @internal_calls += 1
      raise NegativeTestError.new unless @elapsed == Duration.new(2)
    end
  end

  describe TestInitialElapsed do
    describe "simulation" do
      it "time might be negative at initialization" do
        atom = TestInitialElapsed.new(:testneg)
        sim = Quartz::Simulation.new(atom, duration: Quartz::Duration::INFINITY)

        sim.initialize_simulation
        atom.time_advance.should eq(Duration.new(2))
        atom.output_calls.should eq(0)
        atom.internal_calls.should eq(0)
        atom.generated.should be_false

        sim.step

        atom.output_calls.should eq(1)
        atom.internal_calls.should eq(1)
        atom.generated.should be_true
        atom.time_advance.should eq(Quartz::Duration::INFINITY)
      end
    end
  end
end
