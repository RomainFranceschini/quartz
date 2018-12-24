require "../spec_helper"

private module LoopScenario
  class M < Quartz::AtomicModel
    def initialize(name)
      super(name)
    end

    getter output_calls : Int32 = 0
    getter int_calls : Int32 = 0

    def external_transition(bag)
    end

    def output
      @output_calls += 1
    end

    def internal_transition
      @int_calls += 1
    end

    def time_advance
      case @int_calls
      when 0
        Duration.new(1)
      when 1
        Duration.new(0)
      else
        Duration::INFINITY
      end
    end
  end

  describe "PDEVS simulation" do
    it "allows ta(s)=0 loops" do
      m = M.new :m
      sim = Quartz::Simulation.new(m)
      sim.initialize_simulation
      sim.step

      m.int_calls.should eq(1)
      m.output_calls.should eq(1)
      m.time_advance.should eq(Duration.new(0))
      sim.virtual_time.to_i.should eq(1)

      sim.step

      m.int_calls.should eq(2)
      m.output_calls.should eq(2)
      m.time_advance.should eq(Duration::INFINITY)
      sim.virtual_time.to_i.should eq(1)
    end
  end
end
