require "../src/quartz"
require "big"

class MyType
  include Quartz::Transferable
end

struct BigInt
  include Quartz::Transferable
end

class Foo < Quartz::AtomicModel
  output foo1, foo2

  state_var phase : Symbol = :generate

  def time_advance : Quartz::Duration
    if phase == :generate
      Quartz.duration(0)
    else
      Quartz::Duration::INFINITY
    end
  end

  def internal_transition
    @phase = :idle
  end

  def output
    post MyType.new, :foo1
    post BigInt.new(1), :foo2
  end

  def external_transition(bag)
  end
end

class Bar < Quartz::AtomicModel
  include Quartz::PassiveBehavior

  input foo1, foo2

  def external_transition(bag)
    mytype = bag[input_port(:foo1)].first.raw.as(MyType)
    bigi = bag[input_port(:foo2)].first.raw.as(BigInt)

    pp mytype
    pp bigi
  end
end

class PortObserver
  include Quartz::Observer

  def initialize(port : Quartz::OutputPort)
    port.add_observer(self)
  end

  def update(port, info)
    if port.is_a?(Quartz::OutputPort) && info
      host = port.host.as(Quartz::AtomicModel)
      value = info[:payload]
      time = info[:time]
      puts "#{host.name}@#{port.name} sent #{value} at #{time}"
    end
  end
end

model = Quartz::CoupledModel.new(:coupled)
foo = Foo.new(:foo)
model << foo
bar = Bar.new(:bar)
model << bar

model.attach :foo1, to: :foo1, between: foo, and: bar
model.attach :foo2, to: :foo2, between: foo, and: bar

PortObserver.new(foo.output_port(:foo1))
PortObserver.new(foo.output_port(:foo2))

sim = Quartz::Simulation.new(model, duration: Quartz.duration(20))
sim.simulate
