require "./test_helper"

class ObserverTestError < Exception; end

def fail_unless(passes : Bool)
  raise ObserverTestError.new if passes == false
end

class Foo < DEVS::AtomicModel
  @sigma = 0

  def initialize(name)
    super(name)
    add_output_port :out
  end

  def internal_transition
    @sigma = DEVS::INFINITY
  end

  def output
    post "value", :out
  end
end

class PortObserver
  include DEVS::PortObserver

  getter calls : Int32 = 0
  getter port : DEVS::Port?
  getter value : DEVS::Any?

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
  include DEVS::TransitionObserver

  getter calls : Int32 = 0

  def initialize(@model : DEVS::Transitions)
    @model.add_observer(self)
  end

  def update(model, transition)
    @calls += 1
  end
end

model = Foo.new(:foo)
po = PortObserver.new(model.output_port(:out))
to = TransitionObserver.new(model)

sim = DEVS::Simulation.new(model)
sim.simulate

fail_unless po.calls == 1
fail_unless to.calls == 2

fail_unless po.port == model.output_port(:out)
fail_unless po.value == "value"

puts "test observers --> OK"
