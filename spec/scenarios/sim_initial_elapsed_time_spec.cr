require "../spec_helper"

private module InitialElapsedTimeScenario
  class TestInitialElapsed < Quartz::AtomicModel
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0
    getter generated : Bool = false

    # Set the initial elapsed time to 1
    @elapsed = Duration.new(1)

    def external_transition(bag)
    end

    def time_advance : Duration
      @generated ? Duration::INFINITY : Duration.new(2)
    end

    def output
      @output_calls += 1
    end

    def internal_transition
      @generated = true
      @internal_calls += 1
    end
  end

  describe TestInitialElapsed do
    describe "simulation" do
      it "first event depends on initial elapsed time" do
        atom = TestInitialElapsed.new(:testneg)
        sim = Quartz::Simulation.new(atom, duration: Quartz::Duration::INFINITY)

        sim.initialize_simulation
        atom.time_advance.should eq(Duration.new(2))
        atom.output_calls.should eq(0)
        atom.internal_calls.should eq(0)
        atom.generated.should be_false

        sim.virtual_time.to_i.should eq(0)
        sim.step
        sim.virtual_time.to_i.should eq(1)

        atom.output_calls.should eq(1)
        atom.internal_calls.should eq(1)
        atom.generated.should be_true
        atom.time_advance.should eq(Quartz::Duration::INFINITY)
      end
    end
  end
end
