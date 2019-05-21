require "../spec_helper"

private module ConflictScenario
  class ConflictTestError < Exception; end

  class G < Quartz::AtomicModel
    include PassiveBehavior

    def initialize(name)
      super(name)
      @sigma = Duration.new(0)
      add_output_port :out
    end

    getter output_calls : Int32 = 0
    getter int_calls : Int32 = 0

    def confluent_transition(bag)
      raise ConflictTestError.new
    end

    def output
      @output_calls += 1
      post "value", :out
    end

    def internal_transition
      @int_calls += 1
      @sigma = Duration::INFINITY
    end

    def time_advance
      @sigma
    end
  end

  class R < Quartz::AtomicModel
    def initialize(name)
      super(name)
      @sigma = Duration.new(0)
      add_input_port :in
    end

    getter con_calls : Int32 = 0
    getter output_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new
    getter bags : Array(Hash(InputPort, Array(Quartz::Any))) = Array(Hash(InputPort, Array(Quartz::Any))).new

    def external_transition(bag)
      raise ConflictTestError.new
    end

    def confluent_transition(bag)
      @con_calls += 1

      @elapsed_values << @elapsed
      @bags << bag.dup

      @sigma = Duration::INFINITY
    end

    def internal_transition
      raise ConflictTestError.new
    end

    def output
      @output_calls += 1
    end

    def time_advance
      @sigma
    end
  end

  class R2 < Quartz::AtomicModel
    @sigma : Quartz::Duration

    def initialize(name)
      super(name)
      @sigma = Duration::INFINITY
      add_input_port :in
    end

    getter ext_calls : Int32 = 0
    getter output_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new
    getter bags : Array(Hash(InputPort, Array(Quartz::Any))) = Array(Hash(InputPort, Array(Quartz::Any))).new

    def external_transition(bag)
      @ext_calls += 1

      @elapsed_values << @elapsed
      @bags << bag.dup
    end

    def confluent_transition(bag)
      raise ConflictTestError.new
    end

    def internal_transition
      raise ConflictTestError.new
    end

    def output
      @output_calls += 1
    end

    def time_advance
      @sigma
    end
  end

  class PDEVSDeltaCon < Quartz::CoupledModel
    getter g, r, r2

    def initialize
      super("test_pdevs_delta_con")

      @r = R.new :R
      @r2 = R2.new :R2
      @g = G.new :G

      self << @r << @g << @r2

      attach(:out, to: :in, between: :G, and: :R)
      attach(:out, to: :in, between: :G, and: :R2)
    end
  end

  describe PDEVSDeltaCon do
    describe "∂con is called when a conflict occur" do
      it "does for full hierarchy" do
        m = PDEVSDeltaCon.new
        sim = Quartz::Simulation.new(m, maintain_hierarchy: true)
        sim.simulate

        m.r.con_calls.should eq(1)
        m.r.elapsed_values.first.should eq(Duration.new(0))
        m.r.bags.first.has_key?(m.r.input_port(:in)).should be_true
        m.r.bags.first[m.r.input_port(:in)].should eq(["value"])
        m.r.bags.first.keys.size.should eq(1)

        m.r2.ext_calls.should eq(1)
        m.r2.elapsed_values.first.should eq(Duration.new(0))
        m.r2.bags.first.has_key?(m.r2.input_port(:in)).should be_true
        m.r2.bags.first[m.r2.input_port(:in)].should eq(["value"])
        m.r2.bags.first.keys.size.should eq(1)

        m.g.int_calls.should eq(1)
        m.g.output_calls.should eq(1)
      end

      it "does with flattening" do
        m = PDEVSDeltaCon.new
        sim = Quartz::Simulation.new(m, maintain_hierarchy: false)
        sim.simulate

        m.r.con_calls.should eq(1)
        m.r.elapsed_values.first.should eq(Duration.new(0))
        m.r.bags.first.has_key?(m.r.input_port(:in)).should be_true
        m.r.bags.first[m.r.input_port(:in)].should eq(["value"])
        m.r.bags.first.keys.size.should eq(1)

        m.r2.ext_calls.should eq(1)
        m.r2.elapsed_values.first.should eq(Duration.new(0))
        m.r2.bags.first.has_key?(m.r2.input_port(:in)).should be_true
        m.r2.bags.first[m.r2.input_port(:in)].should eq(["value"])
        m.r2.bags.first.keys.size.should eq(1)

        m.g.int_calls.should eq(1)
        m.g.output_calls.should eq(1)
      end
    end
  end
end
