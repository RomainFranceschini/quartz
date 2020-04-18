require "../src/quartz"

class LotkaVolterra < Quartz::DTSS::AtomicModel
  delta 10, milli # euler integration step

  state x : Float64 = 1.0,
    y : Float64 = 1.0,
    alpha : Float64 = 5.2, # prey reproduction rate
    beta : Float64 = 3.4,  # predator per prey mortality rate
    gamma : Float64 = 2.1, # predator mortality rate
    delta : Float64 = 1.4  # predator per prey reproduction rate

  def transition(_messages)
    dxdt = ((x * alpha) - (beta * x * y))
    dydt = (-(gamma * y) + (delta * x * y))

    self.x += self.time_delta.to_f * dxdt
    self.y += self.time_delta.to_f * dydt
  end

  def output
  end
end

class Tracer
  include Quartz::Hooks::Notifiable
  include Quartz::Observer

  @file : File?

  SPACES = 30

  def initialize(model, notifier)
    notifier.subscribe(Quartz::Hooks::PRE_INIT, self)
    notifier.subscribe(Quartz::Hooks::POST_SIMULATION, self)
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
    else
      # no-op
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
sim = Quartz::Simulation.new(model, scheduler: :binary_heap, duration: Quartz.duration(10))
Tracer.new(model, sim.notifier)

sim.simulate

puts sim.transition_stats[:TOTAL]
puts sim.elapsed_secs

puts "Dataset written to 'lotkavolterra.dat'."
puts "Run 'gnuplot -e \"plot 'lotkavolterra.dat' u 1:2 w l t 'preys', '' u 1:3 w l t 'predators'; pause -1;\"' to graph output"
