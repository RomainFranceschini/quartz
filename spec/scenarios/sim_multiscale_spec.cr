require "../spec_helper"

private module MultiscaleScenario
  class MsgTestError < Exception; end

  class FineGen < Quartz::AtomicModel
    output pout

    precision Quartz::Scale::MICRO

    state_var delay_min : Int32 = 10
    state_var delay_max : Int32 = 1000

    def external_transition(bag)
    end

    def output
      post nil, on: :pout
    end

    def internal_transition
    end

    def time_advance : Quartz::Duration
      delay_us = rand(delay_min..delay_max)
      Quartz.duration(delay_us, micro)
    end
  end

  class Gen < Quartz::AtomicModel
    output pout

    precision Quartz::Scale::MICRO

    getter int_calls : Int32 = 0

    def external_transition(bag)
    end

    def output
      post nil, on: :pout
    end

    def internal_transition
      @int_calls += 1
    end

    def time_advance : Quartz::Duration
      Quartz.duration(1)
    end
  end

  class Receiver < Quartz::AtomicModel
    input pin
    include Quartz::PassiveBehavior
  end

  class TestMultiscaleOutput < Quartz::CoupledModel
    getter g1, g2, r

    def initialize
      super("test_multiscale_output")

      @r = Receiver.new :R
      @g1 = FineGen.new :G1
      @g2 = Gen.new :G2

      self << @r << @g1 << @g2

      attach(:pout, to: :pin, between: :G1, and: :R)
      attach(:pout, to: :pin, between: :G2, and: :R)
    end
  end

  describe "Multiscale Test" do
    describe "Multiscale Outputs" do
      it "models planned at different scales are properly scheduled" do
        m = TestMultiscaleOutput.new
        sim = Quartz::Simulation.new(
          m,
          maintain_hierarchy: true,
          duration: Quartz.duration(2)
        )

        sim.simulate

        m.g2.int_calls.should eq(2)
      end
    end
  end
end
