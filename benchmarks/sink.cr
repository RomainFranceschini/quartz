require "../src/quartz"

class Sink < Quartz::AtomicModel
  state do
    var phase : Symbol = :idle
  end

  def time_advance : Quartz::Duration
    if phase == :idle
      Quartz::Duration::INFINITY
    else
      Quartz::Duration.new(RND.rand(0i64..Quartz::Duration::MULTIPLIER_MAX))
    end
  end

  def external_transition(messages)
    state.phase = :active
  end

  def internal_transition
    state.phase = :idle
  end

  def output
    each_output_port { |port| post(name, port) }
  end
end

class Generator < Quartz::AtomicModel
  output :out

  state { var phase : Symbol = :generate }

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
    state.phase = :idle if @events == 0
  end

  def external_transition(bag)
  end
end

class Collector < Quartz::AtomicModel
  include Quartz::PassiveBehavior
  input :in
end

class CoupledSink < Quartz::CoupledModel
  def initialize(gen, col, events)
    super(:sink)

    sink = Sink.new(:sink)
    self << sink

    gen.times do |i|
      g = Generator.new("gen_#{i}", events)
      self << g
      attach(:out, to: "in_#{i}", between: g, and: sink)
    end

    col.times do |i|
      c = Collector.new("col_#{i}")
      self << c
      attach("out_#{i}", to: :in, between: sink, and: c)
    end
  end
end

RND = Random.new(65489)
Quartz.set_no_log_backend

root = CoupledSink.new(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i)
simulation = Quartz::Simulation.new(
  root,
  maintain_hierarchy: true,
  scheduler: :binary_heap
)

simulation.simulate

puts simulation.transition_stats[:TOTAL]
puts simulation.elapsed_secs
