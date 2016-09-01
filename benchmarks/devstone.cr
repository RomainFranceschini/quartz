require "../src/quartz"

module DEVStone
  class Model < Quartz::AtomicModel
    def initialize(name)
      super(name)
      add_input_port :in1
      add_input_port :in2
      add_output_port :out1
      add_output_port :out2
    end

    def external_transition(messages)
      #puts "#{name} received #{messages[input_ports[:in1]]} at #{time}(+#{elapsed})"
      @sigma = rand
    end

    def internal_transition
      @sigma = Quartz::INFINITY
    end

    def output
      output_ports.each_key { |port| post(name, port) }
    end
  end

  class Generator < Quartz::AtomicModel
    def initialize(name)
      super(name)
      @sigma = 1
      add_output_port :out
    end

    def output
      post(name, :out)
    end

    def internal_transition
      @sigma = Quartz::INFINITY
    end
  end

  class Collector < Quartz::AtomicModel
    def initialize(name)
      super(name)
      add_input_port :in
    end

    def external_transition(messages)
      puts "#{name} received #{messages.values} !!"
    end
  end

  class CoupledRecursion < Quartz::CoupledModel
    def initialize(name, coupling_type, width, level, depth)
      super(name)

      add_input_port :in
      add_output_port :out

      if level == depth-1 # deepest level
        model = Model.new("am_l#{level+1}n1")
        self << model
        attach_input(:in, to: :in1, of: model)
        attach_output(:out1, of: model, to: :out)
      else # upper levels
        model = CoupledRecursion.new("cm_#{level+1}", coupling_type, width, level+1, depth)
        self << model
        attach_input(:in, to: :in, of: model)
        attach_output(:out, of: model, to: :out)

        models = [] of Model
        (width-1).times do |i|
          atomic = Model.new("am_l#{level+1}n#{i+1}")
          self << atomic
          models << atomic
          attach_input(:in, to: :in1, of: atomic)
        end

        if coupling_type > 1
          (width-2).times do |i|
            attach(:out1, to: :in1, between: models[i], and: models[i+1])
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

      #PortObserver.new(self[:generator].output_port(:out))
      #ModelObserver.new(self[:generator] as DEVS::AtomicModel)
      #ModelObserver.new(self[:collector] as DEVS::AtomicModel)
    end
  end
end

class PortObserver
  include Quartz::PortObserver

  def initialize(port)
    port.add_observer(self)
  end

  def update(port, value)
    host = port.host.as(Quartz::AtomicModel)
    puts "#{host.name}@#{port.name} sent #{value} at #{host.time}"
  end
end

class ModelObserver
  include Quartz::TransitionObserver

  def initialize(model)
    model.add_observer(self)
  end

  def update(model, kind)
    puts "model #{model.name} changed state after transition #{kind}"
  end
end

root = DEVStone::DEVStone.new(2, ARGV[0].to_i, ARGV[1].to_i)
simulation = Quartz::Simulation.new(root, maintain_hierarchy: false)

simulation.simulate

puts simulation.transition_stats.not_nil![:TOTAL]
puts simulation.elapsed_secs
