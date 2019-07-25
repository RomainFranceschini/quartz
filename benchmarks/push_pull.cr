require "../src/quartz"

class Worker < Quartz::AtomicModel
  input :in
  output :out

  state_var phase : Symbol = :idle

  def time_advance : Quartz::Duration
    if phase == :idle
      Quartz::Duration::INFINITY
    else
      Quartz::Duration.new(RND.rand(0i64..Quartz::Duration::MULTIPLIER_MAX))
    end
  end

  def external_transition(bag)
    @phase = :active
  end

  def internal_transition
    @phase = :idle
  end

  def output
    each_output_port { |port| post(name, port) }
  end
end

class Generator < Quartz::AtomicModel
  output :out

  state_var phase : Symbol = :generate

  def time_advance : Quartz::Duration
    case phase
    when :generate then Quartz.duration(1)
    else                Quartz::Duration::INFINITY
    end
  end

  def initialize(name, @events : Int32)
    super(name)
  end

  def output
    post(name, :out)
  end

  def internal_transition
    @events -= 1
    @phase = :idle if @events == 0
  end

  def external_transition(bag)
  end
end

class Collector < Quartz::AtomicModel
  include Quartz::PassiveBehavior
  input :in
end

class PushPull < Quartz::CoupledModel
  def initialize(workers : Int, events : Int)
    super(:sink)

    g = Generator.new(:gen, events)
    self << g

    c = Collector.new(:col)
    self << c

    workers.times do |i|
      w = Worker.new("worker_#{i}")
      self << w
      attach(:out, to: :in, between: g, and: w)
      attach(:out, to: :in, between: w, and: c)
    end
  end
end

RND = Random.new(87455)

root = PushPull.new(ARGV[0].to_i, ARGV[1].to_i)
simulation = Quartz::Simulation.new(
  root,
  maintain_hierarchy: true,
  scheduler: :binary_heap,
  loggers: Quartz::Loggers.new(false)
)

simulation.simulate

puts simulation.transition_stats[:TOTAL]
puts simulation.elapsed_secs
