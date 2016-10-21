require "../spec_helper"

private module ObservedSimulationScenario
  class ObserverTestError < Exception; end

  class Foo < Quartz::AtomicModel
    @sigma = 0

    def initialize(name)
      super(name)
      add_output_port :out
    end

    def internal_transition
      @sigma = Quartz::INFINITY
    end

    def output
      post "value", :out
    end
  end

  class PortObserver
    include Quartz::PortObserver

    getter calls : Int32 = 0
    getter port : Quartz::Port?
    getter value : Quartz::Any?

    def initialize(port)
      port.add_observer(self)
    end

    def update(port, value)
      @calls += 1
      @port = port
      @value = value
    end
  end

  class TransitionObserver
    include Quartz::TransitionObserver

    getter calls : Int32 = 0

    def initialize(@model : Quartz::Observable(Quartz::TransitionObserver))
      @model.add_observer(self)
    end

    def update(model, transition)
      @calls += 1
    end
  end

  describe "Observered simulation scenario" do
    describe "port observer" do
      it "is notified when a value is dropped on an output port" do
        model = Foo.new(:foo)
        po = PortObserver.new(model.output_port(:out))
        sim = Quartz::Simulation.new(model)
        sim.simulate

        po.calls.should eq(1)
        po.port.should eq(model.output_port(:out))
      end
    end

    describe "transition observer" do
      it "is notified for each transition" do
        model = Foo.new(:foo)
        to = TransitionObserver.new(model)
        sim = Quartz::Simulation.new(model)
        sim.simulate

        # init and internal
        to.calls.should eq(2)
      end
    end
  end
end
