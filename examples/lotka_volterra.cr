require "../src/quartz"

class LotkaVolterra < Quartz::AtomicModel

  state_var x : Float64 = 1.0
  state_var y : Float64 = 1.0

  state_var alpha : Float64 = 5.2     # prey reproduction rate
  state_var beta : Float64 = 3.4      # predator per prey mortality rate
  state_var gamma : Float64 = 2.1     # predator mortality rate
  state_var delta : Float64 = 1.4     # predator per prey reproduction rate

  @sigma = 0.0001                     # euler integration

  def internal_transition
    dxdt = ((@x * @alpha) - (@beta * @x * @y))
    dydt = (-(@gamma * @y) + (@delta * @x * @y))

    @x += @sigma * dxdt
    @y += @sigma * dydt
  end
end

class Plotter
  include Quartz::Hooks::Notifiable
  include Quartz::Observer

  @file : File?

  SPACES = 30

  def initialize(model)
    Quartz::Hooks.notifier.subscribe(:before_simulation_initialization_hook, self)
    Quartz::Hooks.notifier.subscribe(:after_simulation_hook, self)
    model.add_observer(self)
  end

  def notify(hook)
    case hook
    when :before_simulation_initialization_hook
      @file = File.new("lotkavolterra.dat", "w+")
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s %-#{SPACES}s\n", 't', 'x', 'y')
    when :after_simulation_hook
      @file.not_nil!.close
      @file = nil
    end
  end

  def update(model)
    if model.is_a?(LotkaVolterra)
      lotka = model.as(LotkaVolterra)
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s %-#{SPACES}s\n", lotka.time, lotka.x, lotka.y)
    end
  end
end

model = LotkaVolterra.new(:LotkaVolterra)
Plotter.new(model)
sim = Quartz::Simulation.new(model, duration: 20)

sim.simulate

puts "Dataset written to 'lotkavolterra.dat'."
puts "Run 'gnuplot -e \"plot 'lotkavolterra.dat' u 1:2 w l t 'preys', '' u 1:3 w l t 'predators'; pause -1;\"' to graph output"
