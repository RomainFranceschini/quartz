require "../spec_helper"

private module MsgScenario
  class MsgTestError < Exception; end

  class G < Quartz::AtomicModel
    def initialize(name)
      super(name)
      @sigma = Duration.new(1)
      add_output_port :out
    end

    getter output_calls : Int32 = 0
    getter int_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new

    def output
      @output_calls += 1
      post "value", :out
    end

    def internal_transition
      @int_calls += 1
      @elapsed_values << @elapsed
      @sigma = Duration::INFINITY
    end

    def time_advance
      @sigma
    end

    def external_transition(bag)
    end
  end

  class R < Quartz::AtomicModel
    include PassiveBehavior

    def initialize(name)
      super(name)
      add_input_port :in
    end

    getter ext_calls : Int32 = 0
    getter int_calls : Int32 = 0
    getter output_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new

    def external_transition(bag)
      @ext_calls += 1
      @elapsed_values << @elapsed
      raise MsgTestError.new unless bag[input_port(:in)] == ["value", "value"]
    end
  end

  class TestPDEVSMsg < Quartz::CoupledModel
    getter g1, g2, r

    def initialize
      super("test_pdevs_msg")

      @r = R.new :R
      @g1 = G.new :G1
      @g2 = G.new :G2

      self << @r << @g1 << @g2

      attach(:out, to: :in, between: :G1, and: :R)
      attach(:out, to: :in, between: :G2, and: :R)
    end
  end

  class TestPDEVSCoupledMsg < Quartz::CoupledModel
    getter g1, g2, r

    def initialize
      super("test_pdevs_coupled_msg")

      @r = R.new :R
      @g1 = G.new :G1
      @g2 = G.new :G2

      gen = Quartz::CoupledModel.new(:GEN)
      gen.add_output_port :out
      gen << @g1 << @g2
      gen.attach_output(:out, to: :out, of: @g1)
      gen.attach_output(:out, to: :out, of: @g2)

      recv = Quartz::CoupledModel.new(:RECV)
      recv.add_input_port :in
      recv << @r
      recv.attach_input(:in, to: :in, of: @r)

      self << gen << recv
      attach(:out, to: :in, between: gen, and: recv)
    end
  end

  describe "MessageTest" do
    describe "with IC, EOC and EIC couplings involved" do
      describe "transition are properly called" do
        it "for full hierarchy" do
          m = TestPDEVSCoupledMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: true)
          sim.simulate

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values.first.should eq(Duration.new(1))

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(1)

          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(1)

          m.g1.elapsed_values.first.should eq(Duration.new(0))
          m.g2.elapsed_values.first.should eq(Duration.new(0))
        end

        it "with flattening" do
          m = TestPDEVSCoupledMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: false)
          sim.simulate

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values.first.should eq(Duration.new(1))

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(1)

          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(1)

          m.g1.elapsed_values.first.should eq(Duration.new(0))
          m.g2.elapsed_values.first.should eq(Duration.new(0))
        end
      end
    end

    describe "with IC couplings only" do
      describe "transition are properly called" do
        it "for full hierarchy" do
          m = TestPDEVSMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: true)
          sim.simulate

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values.first.should eq(Duration.new(1))

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(1)

          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(1)

          m.g1.elapsed_values.first.should eq(Duration.new(0))
          m.g2.elapsed_values.first.should eq(Duration.new(0))
        end

        it "with flattening" do
          m = TestPDEVSMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: false)
          sim.simulate

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values.first.should eq(Duration.new(1))

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(1)

          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(1)

          m.g1.elapsed_values.first.should eq(Duration.new(0))
          m.g2.elapsed_values.first.should eq(Duration.new(0))
        end
      end
    end
  end
end
