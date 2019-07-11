require "../src/quartz"

module DEVStone
  class Model < Quartz::AtomicModel
    input :in1, :in2
    output :out1, :out2

    state_var phase : Symbol = :active

    def time_advance
      if phase == :active
        Quartz::Duration.new(RND.rand(5000))
      else
        Quartz::Duration::INFINITY
      end
    end

    def external_transition(messages)
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

    def time_advance
      if phase == :generate
        Quartz::Duration.new(1)
      else
        Quartz::Duration::INFINITY
      end
    end

    def output
      post(name, :out)
    end

    def internal_transition
      @phase = :idle
    end

    def external_transition(bag)
    end
  end

  class Collector < Quartz::AtomicModel
    include Quartz::PassiveBehavior
    input :in
  end

  class CoupledRecursion < Quartz::CoupledModel
    input :in
    output :out

    def initialize(name, coupling_type, width, level, depth)
      super(name)

      if level == depth - 1 # deepest level
        model = Model.new("am_l#{level + 1}n1")
        self << model
        attach_input(:in, to: :in1, of: model)
        attach_output(:out1, of: model, to: :out)
      else # upper levels
        model = CoupledRecursion.new("cm_#{level + 1}", coupling_type, width, level + 1, depth)
        self << model
        attach_input(:in, to: :in, of: model)
        attach_output(:out, of: model, to: :out)

        models = [] of Model
        (width - 1).times do |i|
          atomic = Model.new("am_l#{level + 1}n#{i + 1}")
          self << atomic
          models << atomic
          attach_input(:in, to: :in1, of: atomic)
        end

        if coupling_type > 1
          (width - 2).times do |i|
            attach(:out1, to: :in1, between: models[i], and: models[i + 1])
          end
        end
      end
    end
  end

  class DEVStone < Quartz::CoupledModel
    def initialize(coupling_type, width, depth)
      super(:devstone)
      self << Generator.new(:generator)
      self << CoupledRecursion.new(:cm_0, coupling_type, width, 0, depth)
      self << Collector.new(:collector)

      attach(:out, to: :in, between: :generator, and: :cm_0)
      attach(:out, to: :in, between: :cm_0, and: :collector)

      # PortObserver.new(self[:generator].output_port(:out))
      # ModelObserver.new(self[:generator] as DEVS::AtomicModel)
      # ModelObserver.new(self[:collector] as DEVS::AtomicModel)
    end
  end
end

class PortObserver
  include Quartz::Observer

  def initialize(port : OutputPort)
    port.add_observer(self)
  end

  def update(port, info)
    if port.is_a?(Quartz::OutputPort) && info
      host = port.host.as(Quartz::AtomicModel)
      puts "#{host.name}@#{port.name} sent #{info[:payload]}"
    end
  end
end

class ModelObserver
  include Quartz::Observer

  def initialize(model)
    model.add_observer(self)
  end

  def update(model, info)
    if model.is_a?(Quartz::AtomicModel) && info
      puts "model #{model.name} changed state after transition #{info[:transition]}"
    end
  end
end

RND = Random.new(1234)

root = DEVStone::DEVStone.new(2, ARGV[0].to_i, ARGV[1].to_i)
simulation = Quartz::Simulation.new(
  root,
  maintain_hierarchy: false,
  scheduler: :binary_heap,
  loggers: Quartz::Loggers.new(false)
)

simulation.simulate

puts simulation.transition_stats[:TOTAL]
puts simulation.elapsed_secs
