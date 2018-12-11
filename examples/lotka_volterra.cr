require "../src/quartz"

class LotkaVolterra < Quartz::AtomicModel
  state_var x : Float64 = 1.0
  state_var y : Float64 = 1.0

  @precision = Quartz::Scale::NANO

  state_var alpha : Float64 = 5.2 # prey reproduction rate
  state_var beta : Float64 = 3.4  # predator per prey mortality rate
  state_var gamma : Float64 = 2.1 # predator mortality rate
  state_var delta : Float64 = 1.4 # predator per prey reproduction rate

  @sigma = Quartz::Duration.new(100, Quartz::Scale::MICRO) # euler integration

  def internal_transition
    dxdt = ((@x * @alpha) - (@beta * @x * @y))
    dydt = (-(@gamma * @y) + (@delta * @x * @y))

    @x += @sigma.to_f * dxdt
    @y += @sigma.to_f * dydt
  end
end

class Tracer
  include Quartz::Hooks::Notifiable
  include Quartz::Observer

  @file : File?

  SPACES = 30

  def initialize(model)
    Quartz::Hooks.notifier.subscribe(Quartz::Hooks::PRE_INIT, self)
    Quartz::Hooks.notifier.subscribe(Quartz::Hooks::POST_SIMULATION, self)
    model.add_observer(self)
  end

  def notify(hook)
    case hook
    when Quartz::Hooks::PRE_INIT
      @file = File.new("lotkavolterra.dat", "w+")
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s %-#{SPACES}s\n", 't', 'x', 'y')
    when Quartz::Hooks::POST_SIMULATION
      @file.not_nil!.close
      @file = nil
    end
  end

  def update(model, info)
    if model.is_a?(LotkaVolterra)
      lotka = model.as(LotkaVolterra)
      time = info[:time].as(Quartz::TimePoint)
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s %-#{SPACES}s\n", time.to_s, lotka.x, lotka.y)
    end
  end
end

model = LotkaVolterra.new(:LotkaVolterra)
Tracer.new(model)
sim = Quartz::Simulation.new(model, scheduler: :binary_heap, duration: Quartz.duration(20))

sim.simulate

puts "Dataset written to 'lotkavolterra.dat'."
puts "Run 'gnuplot -e \"plot 'lotkavolterra.dat' u 1:2 w l t 'preys', '' u 1:3 w l t 'predators'; pause -1;\"' to graph output"
