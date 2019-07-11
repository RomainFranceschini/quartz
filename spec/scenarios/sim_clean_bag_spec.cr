require "../spec_helper"

private module CleanBagScenario
  class G < Quartz::AtomicModel
    @quantum : Int64

    def initialize(name, quantum : Int)
      super(name)
      @quantum = quantum.to_i64
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
    end

    def external_transition(bag)
    end

    def time_advance
      Duration.new(@quantum)
    end
  end

  class R < Quartz::AtomicModel
    include PassiveBehavior

    def initialize(name)
      super(name)
      add_input_port :in1
      add_input_port :in2
    end

    getter ext_calls : Int32 = 0
    getter int_calls : Int32 = 0
    getter output_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new
    getter bags : Array(Hash(InputPort, Array(Quartz::Any))) = Array(Hash(InputPort, Array(Quartz::Any))).new

    def external_transition(bag)
      @ext_calls += 1
      @elapsed_values << @elapsed
      @bags << bag.dup
    end
  end

  class TestSimpleMsg < Quartz::CoupledModel
    getter g1, g2, r

    def initialize
      super("test_pdevs_msg_bag")

      @r = R.new :R
      @g1 = G.new :G1, 1
      @g2 = G.new :G2, 2

      self << @r << @g1 << @g2

      attach(:out, to: :in1, between: :G1, and: :R)
      attach(:out, to: :in2, between: :G2, and: :R)
    end
  end

  class TestNestedMsg < Quartz::CoupledModel
    getter g1, g2, r

    def initialize
      super("test_pdevs_coupled_msg_bag")

      @r = R.new :R
      @g1 = G.new :G1, 1
      @g2 = G.new :G2, 2

      gen = Quartz::CoupledModel.new(:GEN)
      gen.add_output_port :out1
      gen.add_output_port :out2
      gen << @g1 << @g2
      gen.attach_output(:out, of: @g1, to: :out1)
      gen.attach_output(:out, of: @g2, to: :out2)

      recv = Quartz::CoupledModel.new(:RECV)
      recv.add_input_port :in1
      recv.add_input_port :in2
      recv << @r
      recv.attach_input(:in1, to: :in1, of: @r)
      recv.attach_input(:in2, to: :in2, of: @r)

      self << gen << recv
      attach(:out1, to: :in1, between: gen, and: recv)
      attach(:out2, to: :in2, between: gen, and: recv)
    end
  end

  describe "MessageBagTest" do
    describe "with IC couplings only" do
      describe "transition are properly called" do
        it "for full hierarchy" do
          m = TestSimpleMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: true, loggers: Loggers.new(false))

          sim.initialize_simulation
          sim.step

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(0)
          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(0)
          m.g1.elapsed_values[0].should eq(Duration.new(0))

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[0].should eq(Duration.new(1))
          m.r.bags[0].keys.size.should eq(1)
          m.r.bags[0].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[0][m.r.input_port(:in1)].should eq(["value"])

          sim.step

          m.r.ext_calls.should eq(2)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[1].should eq(Duration.new(1))
          m.r.bags[1].keys.size.should eq(2)
          m.r.bags[1].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[1].has_key?(m.r.input_port(:in2)).should be_true
          m.r.bags[1][m.r.input_port(:in1)].should eq(["value"])
          m.r.bags[1][m.r.input_port(:in2)].should eq(["value"])

          m.g1.int_calls.should eq(2)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(2)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[1].should eq(Duration.new(0))
          m.g2.elapsed_values[0].should eq(Duration.new(0))

          sim.step

          m.r.ext_calls.should eq(3)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[2].should eq(Duration.new(1))
          m.r.bags[2].keys.size.should eq(1)
          m.r.bags[2].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[2].has_key?(m.r.input_port(:in2)).should be_false
          m.r.bags[2][m.r.input_port(:in1)].should eq(["value"])

          m.g1.int_calls.should eq(3)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(3)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[2].should eq(Duration.new(0))
        end

        it "with flattening" do
          m = TestSimpleMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: false, loggers: Loggers.new(false))

          sim.initialize_simulation
          sim.step

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(0)
          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(0)
          m.g1.elapsed_values[0].should eq(Duration.new(0))

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[0].should eq(Duration.new(1))
          m.r.bags[0].keys.size.should eq(1)
          m.r.bags[0].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[0][m.r.input_port(:in1)].should eq(["value"])

          sim.step

          m.r.ext_calls.should eq(2)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[1].should eq(Duration.new(1))
          m.r.bags[1].keys.size.should eq(2)
          m.r.bags[1].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[1].has_key?(m.r.input_port(:in2)).should be_true
          m.r.bags[1][m.r.input_port(:in1)].should eq(["value"])
          m.r.bags[1][m.r.input_port(:in2)].should eq(["value"])

          m.g1.int_calls.should eq(2)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(2)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[1].should eq(Duration.new(0))
          m.g2.elapsed_values[0].should eq(Duration.new(0))

          sim.step

          m.r.ext_calls.should eq(3)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[2].should eq(Duration.new(1))
          m.r.bags[2].keys.size.should eq(1)
          m.r.bags[2].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[2].has_key?(m.r.input_port(:in2)).should be_false
          m.r.bags[2][m.r.input_port(:in1)].should eq(["value"])

          m.g1.int_calls.should eq(3)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(3)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[2].should eq(Duration.new(0))
        end
      end
    end

    describe "with IC, EOC and EIC couplings involved" do
      describe "transition are properly called" do
        it "for full hierarchy" do
          m = TestNestedMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: true, loggers: Loggers.new(false))

          sim.initialize_simulation
          sim.step

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(0)
          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(0)
          m.g1.elapsed_values[0].should eq(Duration.new(0))

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[0].should eq(Duration.new(1))
          m.r.bags[0].keys.size.should eq(1)
          m.r.bags[0].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[0][m.r.input_port(:in1)].should eq(["value"])

          sim.step

          m.r.ext_calls.should eq(2)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[1].should eq(Duration.new(1))
          m.r.bags[1].keys.size.should eq(2)
          m.r.bags[1].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[1].has_key?(m.r.input_port(:in2)).should be_true
          m.r.bags[1][m.r.input_port(:in1)].should eq(["value"])
          m.r.bags[1][m.r.input_port(:in2)].should eq(["value"])

          m.g1.int_calls.should eq(2)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(2)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[1].should eq(Duration.new(0))
          m.g2.elapsed_values[0].should eq(Duration.new(0))

          sim.step

          m.r.ext_calls.should eq(3)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[2].should eq(Duration.new(1))
          m.r.bags[2].keys.size.should eq(1)
          m.r.bags[2].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[2].has_key?(m.r.input_port(:in2)).should be_false
          m.r.bags[2][m.r.input_port(:in1)].should eq(["value"])

          m.g1.int_calls.should eq(3)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(3)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[2].should eq(Duration.new(0))
        end

        it "with flattening" do
          m = TestNestedMsg.new
          sim = Quartz::Simulation.new(m, maintain_hierarchy: false, loggers: Loggers.new(false))

          sim.initialize_simulation
          sim.step

          m.g1.int_calls.should eq(1)
          m.g2.int_calls.should eq(0)
          m.g1.output_calls.should eq(1)
          m.g2.output_calls.should eq(0)
          m.g1.elapsed_values[0].should eq(Duration.new(0))

          m.r.ext_calls.should eq(1)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[0].should eq(Duration.new(1))
          m.r.bags[0].keys.size.should eq(1)
          m.r.bags[0].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[0][m.r.input_port(:in1)].should eq(["value"])

          sim.step

          m.r.ext_calls.should eq(2)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[1].should eq(Duration.new(1))
          m.r.bags[1].keys.size.should eq(2)
          m.r.bags[1].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[1].has_key?(m.r.input_port(:in2)).should be_true
          m.r.bags[1][m.r.input_port(:in1)].should eq(["value"])
          m.r.bags[1][m.r.input_port(:in2)].should eq(["value"])

          m.g1.int_calls.should eq(2)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(2)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[1].should eq(Duration.new(0))
          m.g2.elapsed_values[0].should eq(Duration.new(0))

          sim.step

          m.r.ext_calls.should eq(3)
          m.r.int_calls.should eq(0)
          m.r.output_calls.should eq(0)
          m.r.elapsed_values[2].should eq(Duration.new(1))
          m.r.bags[2].keys.size.should eq(1)
          m.r.bags[2].has_key?(m.r.input_port(:in1)).should be_true
          m.r.bags[2].has_key?(m.r.input_port(:in2)).should be_false
          m.r.bags[2][m.r.input_port(:in1)].should eq(["value"])

          m.g1.int_calls.should eq(3)
          m.g2.int_calls.should eq(1)
          m.g1.output_calls.should eq(3)
          m.g2.output_calls.should eq(1)
          m.g1.elapsed_values[2].should eq(Duration.new(0))
        end
      end
    end
  end
end
