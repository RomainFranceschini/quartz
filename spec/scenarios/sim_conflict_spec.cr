require "../spec_helper"

private module ConflictScenario

  class ConflictTestError < Exception; end

  class G < Quartz::AtomicModel
    def initialize(name)
      super(name)
      @sigma = 1
      add_output_port :out
    end

    getter output_calls : Int32 = 0
    getter int_calls : Int32 = 0

    def output
      @output_calls += 1
      post "value", :out
    end

    def internal_transition
      @int_calls += 1
      @sigma = Quartz::INFINITY
    end
  end

  class R < Quartz::AtomicModel
    def initialize(name)
      super(name)
      @sigma = 1
      add_input_port :in
    end

    getter con_calls : Int32 = 0
    getter output_calls : Int32 = 0

    def external_transition(bag)
      raise ConflictTestError.new
    end

    def confluent_transition(bag)
      @con_calls += 1

      # TODO use observer ?
      raise ConflictTestError.new("elapsed time should eq 0") unless @elapsed == 0
      raise ConflictTestError.new("bag should contain (:in, [\"value\"])") unless bag[input_port(:in)] == ["value"]

      @sigma = Quartz::INFINITY
    end

    def internal_transition
      raise ConflictTestError.new
    end

    def output
      @output_calls += 1
    end
  end

  class PDEVSDeltaCon < Quartz::CoupledModel
    getter g, r

    def initialize
      super("test_pdevs_delta_con")

      @r = R.new :R
      @g = G.new :G

      self << @r << @g

      attach(:out, to: :in, between: :G, and: :R)
    end
  end

  describe PDEVSDeltaCon do
    describe "∂con is called when a conflict occur" do
      it "does for full hierarchy" do
        m = PDEVSDeltaCon.new
        sim = Quartz::Simulation.new(m, maintain_hierarchy: false)
        sim.simulate

        m.r.con_calls.should eq(1)
        m.g.int_calls.should eq(1)
        m.g.output_calls.should eq(1)
      end

      it "does with flattening" do
        m = PDEVSDeltaCon.new
        sim = Quartz::Simulation.new(m, maintain_hierarchy: true)
        sim.simulate

        m.r.con_calls.should eq(1)
        m.g.int_calls.should eq(1)
        m.g.output_calls.should eq(1)
      end
    end
  end
end
