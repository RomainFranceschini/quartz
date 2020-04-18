require "../src/quartz"

include Quartz

class SinusGenerator < AtomicModel
  output :signal
  precision :micro

  state(amplitude : Float64 = 1.0,
    frequency : Float64 = 0.5,
    phase : Float64 = 1,
    step : Int32 = 80,
    time : TimePoint = TimePoint.new,
    sigma : Duration,
    pulse : Float64) do
    @sigma = Duration.from(1.0 / frequency / step)
    @pulse = 2.0 * Math::PI * frequency
  end

  def internal_transition
    time.advance by: sigma
  end

  def output
    dt = time.to_f + sigma.to_f
    value = amplitude * Math.sin(pulse * dt + phase)
    post value, on: output_port(:signal)
  end

  def time_advance : Duration
    sigma
  end

  def external_transition(_messages)
    # no-op
  end
end

class Tracer
  include Quartz::Hooks::Notifiable
  include Quartz::Observer

  SPACES = 30
  @file : File?

  def initialize(model, notifier)
    notifier.subscribe(Quartz::Hooks::PRE_INIT, self)
    notifier.subscribe(Quartz::Hooks::POST_SIMULATION, self)
    model.add_observer(self)
  end

  def notify(hook)
    case hook
    when Quartz::Hooks::PRE_INIT
      @file = File.new("sinus.dat", "w+")
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s\n", 't', "sinus")
    when Quartz::Hooks::POST_SIMULATION
      @file.not_nil!.close
      @file = nil
    else
      # no-op
    end
  end

  def update(observable, info)
    if observable.is_a?(Quartz::Port)
      payload = info[:payload].as(Array(Any)).first
      time = info[:time].as(Quartz::TimePoint)
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s\n", time.to_s, payload.to_s)
    end
  end
end

model = SinusGenerator.new(:sinus)
sim = Quartz::Simulation.new(model, scheduler: :binary_heap, duration: Quartz.duration(6))
Tracer.new(model.output_port(:signal), sim.notifier)

sim.simulate
puts sim.transition_stats[:TOTAL]

puts "Dataset written to 'sinus.dat'."
puts "Run 'gnuplot -e \"plot 'sinus.dat' u 1:2 w l t 'signal'; pause -1;\"' to graph output"
