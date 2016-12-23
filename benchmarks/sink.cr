require "../src/quartz"

class Sink < Quartz::AtomicModel
  def external_transition(messages)
    @sigma = rand
  end

  def internal_transition
    @sigma = Quartz::INFINITY
  end

  def output
    each_output_port { |port| post(name, port) }
  end
end

class Generator < Quartz::AtomicModel
  output :out
  @sigma = 1

  def initialize(name, @events : Int32)
    super(name)
  end

  def output
    post(name, :out)
  end

  def internal_transition
    @events -= 1
    @sigma = (@events == 0) ? Quartz::INFINITY : 1
  end
end

class Collector < Quartz::AtomicModel
  input :in

  def external_transition(messages)
  end
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

Quartz.logger = nil

root = CoupledSink.new(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i)
simulation = Quartz::Simulation.new(
  root,
  maintain_hierarchy: true,
  scheduler: :calendar_queue
)

simulation.simulate

#puts simulation.transition_stats[:TOTAL]
puts simulation.elapsed_secs
