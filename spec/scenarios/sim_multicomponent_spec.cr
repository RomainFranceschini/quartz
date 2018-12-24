require "../spec_helper"

private module MultiPDEVSSimulation
  class Generator < Quartz::AtomicModel
    include PassiveBehavior

    output :out

    @sigma = Duration.new(0)

    def output
      post nil, on: :out
    end

    def internal_transition
      @sigma = Duration.new(1)
    end

    def time_advance
      @sigma
    end
  end

  class ComponentA < Quartz::MultiComponent::Component
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0
    getter reaction_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new
    getter time : TimePoint = TimePoint.new

    def internal_transition
      @time = @time.advance(by: Duration.new(1))
      @elapsed_values << @elapsed
      @internal_calls += 1
      Quartz::SimpleHash(Quartz::Name, Quartz::Any).new
    end

    def external_transition(bag)
      Quartz::SimpleHash(Quartz::Name, Quartz::Any).new
    end

    def time_advance
      Duration.new(1)
    end

    def output
      @output_calls += 1
      nil
    end

    def reaction_transition(states)
      @reaction_calls += 1
    end
  end

  class ComponentB < Quartz::MultiComponent::Component
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0
    getter external_calls : Int32 = 0
    getter confluent_calls : Int32 = 0
    getter reaction_calls : Int32 = 0
    getter elapsed_values : Array(Duration) = Array(Duration).new
    getter time : TimePoint = TimePoint.new

    state_var state_count : Int32 = 0

    def internal_transition
      @time = @time.advance(by: Duration.new(1))
      @elapsed_values << @elapsed
      @internal_calls += 1
      Quartz::SimpleHash(Quartz::Name, Quartz::Any).new.tap do |states|
        states.unsafe_assoc(
          self.name,
          Quartz::Any.new(ComponentB::State.new(state_count: @state_count + 1))
        )
      end
    end

    def external_transition(bag)
      @time = @time.advance(by: @elapsed)
      @elapsed_values << @elapsed
      @external_calls += 1
      Quartz::SimpleHash(Quartz::Name, Quartz::Any).new.tap do |states|
        states.unsafe_assoc(
          self.name,
          Quartz::Any.new(ComponentB::State.new(state_count: @state_count + 1))
        )
      end
    end

    def confluent_transition(bag)
      @time = @time.advance(by: Duration.new(1))
      @elapsed_values << @elapsed
      @confluent_calls += 1
      Quartz::SimpleHash(Quartz::Name, Quartz::Any).new.tap do |states|
        states.unsafe_assoc(
          self.name,
          Quartz::Any.new(ComponentB::State.new(state_count: @state_count + 1))
        )
      end
    end

    def time_advance
      Duration.new(1)
    end

    def output
      @output_calls += 1
      nil
    end

    def reaction_transition(states)
      @reaction_calls += 1
      self.state = states.first.last.raw.as(ComponentB::State)
    end
  end

  describe "MultiPDEVS simulation" do
    it "calls time advance only for components being influenced" do
      model = Quartz::MultiComponent::Model.new(:multipdevs)
      ca = ComponentA.new(:CA)
      model << ca
      sim = Quartz::Simulation.new(model)

      sim.initialize_simulation
      sim.step

      ca.output_calls.should eq(1)
      ca.internal_calls.should eq(1)
      ca.reaction_calls.should eq(0)
      ca.time.to_i.should eq(1)
      ca.elapsed_values[0].should eq(Duration.new(0))

      sim.step
      sim.done?.should be_true
    end

    it "calls internal transition when appropriate" do
      model = Quartz::MultiComponent::Model.new(:multipdevs)
      cb = ComponentB.new(:CB)
      model << cb
      sim = Quartz::Simulation.new(model, duration: Duration.new(10))

      sim.each_with_index { |e, i|
        cb.output_calls.should eq(i + 1)
        cb.internal_calls.should eq(i + 1)
        cb.external_calls.should eq(0)
        cb.confluent_calls.should eq(0)
        cb.reaction_calls.should eq(i + 1)
        cb.state_count.should eq(i + 1)
        cb.time.to_i.should eq(i + 1)
        cb.elapsed_values[i].should eq(Duration.new(0))
      }
    end

    it "calls external/confluent transition when appropriate" do
      multipdevs = Quartz::MultiComponent::Model.new(:multipdevs)
      cb = ComponentB.new(:CB)
      multipdevs << cb
      multipdevs.add_input_port(:in)

      model = Quartz::CoupledModel.new(:root)
      gen = Generator.new(:gen)

      model << gen
      model << multipdevs
      model.attach :out, to: :in, between: gen, and: multipdevs

      sim = Quartz::Simulation.new(model)
      sim.initialize_simulation

      sim.step

      cb.output_calls.should eq(0)
      cb.internal_calls.should eq(0)
      cb.external_calls.should eq(1)
      cb.confluent_calls.should eq(0)
      cb.reaction_calls.should eq(1)
      cb.state_count.should eq(1)
      cb.time.to_i.should eq(0)
      cb.elapsed_values[0].should eq(Duration.new(0))

      sim.step
      cb.output_calls.should eq(1)
      cb.internal_calls.should eq(0)
      cb.external_calls.should eq(1)
      cb.confluent_calls.should eq(1)
      cb.reaction_calls.should eq(2)
      cb.state_count.should eq(2)
      cb.time.to_i.should eq(1)
      cb.elapsed_values[1].should eq(Duration.new(0))
    end
  end
end
