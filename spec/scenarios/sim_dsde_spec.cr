require "../spec_helper"

private module DSDESimulation
  class OneTimeModel < Quartz::AtomicModel
    @sigma = Duration.new(20)

    getter output_calls : Int32 = 0
    getter int_calls : Int32 = 0
    getter ext_calls : Int32 = 0

    def external_transition(messages)
      @ext_calls += 1
    end

    def output
      @output_calls += 1
    end

    def internal_transition
      @int_calls += 1
      @sigma = Duration::INFINITY
    end
  end

  class CreateExecutive < Quartz::DSDE::Executive
    getter counter

    def initialize(name)
      super(name)
      @sigma = Duration.new(1)
      @counter = 0
    end

    def internal_transition
      @counter += 1
      add_model_to_network(OneTimeModel.new("M#{@counter}"))
      @sigma = Duration::INFINITY
    end
  end

  class DeleteExecutive < Quartz::DSDE::Executive
    getter counter

    def initialize(name)
      super(name)
      @sigma = Duration.new(5)
      @counter = 0
    end

    def internal_transition
      @counter += 1
      remove_model_from_network(:m1)
      @sigma = Duration::INFINITY
    end
  end

  class UpdateCouplingsExecutive < Quartz::DSDE::Executive
    @sigma = Duration.new(2)

    def internal_transition
      remove_coupling_from_network :out1, from: :in1, between: :m1, and: :m2
      add_coupling_to_network :out2, to: :in2, between: :m1, and: :m2

      @sigma = Duration::INFINITY
    end
  end

  class UpdatePortsExecutive < Quartz::DSDE::Executive
    @sigma = Duration.new(1)

    def internal_transition
      add_input_port_to_network :m1, :in3
      add_output_port_to_network :m1, :out3
      remove_input_port_from_network :m1, :in2
      remove_output_port_from_network :m1, :out2

      @sigma = Duration::INFINITY
    end
  end

  class AtomicWithPorts < Quartz::AtomicModel
    input :in1, :in2
    output :out1, :out2

    @sigma = Duration.new(1)

    getter in1_values = 0
    getter in2_values = 0

    def external_transition(bag)
      if bag.has_key?(input_port(:in1))
        @in1_values += 1
      end

      if bag.has_key?(input_port(:in2))
        @in2_values += 1
      end
    end

    def output
      each_output_port { |op| post(nil, op) }
    end
  end

  describe "DSDE simulation" do
    it "can create new models" do
      executive = CreateExecutive.new(:executive)
      dsde = Quartz::DSDE::CoupledModel.new(:dsde, executive)
      sim = Quartz::Simulation.new(dsde)

      dsde.children_size.should eq(1) # actually, it should be 0 (executive should not be a child)

      sim.simulate

      dsde.children_size.should eq(2)
      executive.counter.should eq(1)
      dsde.has_child?("M1").should be_true

      m1 = dsde["M1"].as(OneTimeModel)
      m1.int_calls.should eq(1)
      m1.ext_calls.should eq(0)
      m1.output_calls.should eq(1)

      sim.virtual_time.to_i.should eq(21)
    end

    it "can destroy existing models" do
      executive = DeleteExecutive.new(:executive)
      dsde = Quartz::DSDE::CoupledModel.new(:dsde, executive)
      m1 = OneTimeModel.new(:m1)
      dsde << m1
      sim = Quartz::Simulation.new(dsde)

      dsde.children_size.should eq(2)

      sim.simulate

      sim.virtual_time.to_i.should eq(5)
      dsde.children_size.should eq(1)

      m1.int_calls.should eq(0)
      m1.ext_calls.should eq(0)
      m1.output_calls.should eq(0)
    end

    it "can add and remove couplings between models" do
      executive = UpdateCouplingsExecutive.new(:executive)
      dsde = Quartz::DSDE::CoupledModel.new(:dsde, executive)
      m1 = AtomicWithPorts.new(:m1)
      m2 = AtomicWithPorts.new(:m2)
      dsde << m1 << m2
      dsde.attach :out1, to: :in1, between: m1, and: m2

      sim = Quartz::Simulation.new(dsde)
      sim.initialize_simulation
      sim.step

      sim.virtual_time.to_i.should eq(1)
      m2.in1_values.should eq(1)
      m2.in2_values.should eq(0)
      dsde.internal_couplings(m1.output_port(:out1)).should eq([m2.input_port(:in1)])
      dsde.internal_couplings(m1.output_port(:out2)).should eq([] of OutputPort)

      sim.step
      sim.virtual_time.to_i.should eq(2)
      m2.in1_values.should eq(2)
      m2.in2_values.should eq(0)
      dsde.internal_couplings(m1.output_port(:out1)).should eq([] of OutputPort)
      dsde.internal_couplings(m1.output_port(:out2)).should eq([m2.input_port(:in2)])

      sim.step
      m2.in1_values.should eq(2)
      m2.in2_values.should eq(1)
      dsde.internal_couplings(m1.output_port(:out1)).should eq([] of OutputPort)
      dsde.internal_couplings(m1.output_port(:out2)).should eq([m2.input_port(:in2)])
    end

    it "can add and remove ports from models" do
      executive = UpdatePortsExecutive.new(:executive)
      dsde = Quartz::DSDE::CoupledModel.new(:dsde, executive)
      m1 = AtomicWithPorts.new(:m1)
      dsde << m1
      sim = Quartz::Simulation.new(dsde)
      sim.initialize_simulation

      m1.input_port_names.should eq([:in1, :in2])
      m1.output_port_names.should eq([:out1, :out2])

      sim.step

      m1.input_port_names.should eq([:in1, :in3])
      m1.output_port_names.should eq([:out1, :out3])
    end
  end
end
