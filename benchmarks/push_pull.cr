require "../src/quartz"

class Worker < Quartz::AtomicModel
  input :in
  output :out

  def external_transition(messages)
    @sigma = Quartz::Duration.new(RND.rand(0i64..Quartz::Duration::MULTIPLIER_MAX))
  end

  def internal_transition
    @sigma = Quartz::Duration::INFINITY
  end

  def output
    each_output_port { |port| post(name, port) }
  end
end

class Generator < Quartz::AtomicModel
  output :out
  @sigma = Quartz.duration(1)

  def initialize(name, @events : Int32)
    super(name)
  end

  def output
    post(name, :out)
  end

  def internal_transition
    @events -= 1
    @sigma = (@events == 0) ? Quartz::Duration::INFINITY : Quartz.duration(1)
  end
end

class Collector < Quartz::AtomicModel
  input :in

  def external_transition(messages)
  end
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

Quartz.logger = nil
RND = Random.new(87455)

root = PushPull.new(ARGV[0].to_i, ARGV[1].to_i)
simulation = Quartz::Simulation.new(
  root,
  maintain_hierarchy: true,
  scheduler: :binary_heap
)

simulation.simulate

puts simulation.transition_stats[:TOTAL]
puts simulation.elapsed_secs
