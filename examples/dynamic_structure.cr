require "../src/quartz"

class OneTimeModel < Quartz::AtomicModel
  state phase : Symbol = :active

  def time_advance : Quartz::Duration
    case phase
    when :active then Quartz.duration(20)
    else              Quartz::Duration::INFINITY
    end
  end

  def external_transition(messages)
    puts "#{name} received #{messages}."
  end

  def internal_transition
    puts "#{name} does something."
    self.phase = :idle
  end

  def output
  end
end

class BirthController < Quartz::DSDE::Executive
  output :birth, :death, :add_coupling, :remove_coupling

  state phase : Symbol = :init,
    counter : Int32 = 0

  def time_advance : Quartz::Duration
    case phase
    when :init          then Quartz.duration(1)
    when :death, :birth then Quartz.duration(5)
    else                     Quartz::Duration::INFINITY
    end
  end

  def internal_transition
    if self.phase == :death
      remove_coupling_from_network(:out, from: :in, between: "model_0", and: "model_#{counter}")
      remove_model_from_network("model_#{counter}")
      self.counter -= 1
      self.phase = :idle
    else
      add_model_to_network(OneTimeModel.new("model_#{counter}"))
      add_coupling_to_network(:out, to: :in, between: "model_0", and: "model_#{counter}") if counter > 0
      self.phase = if self.counter == 2
                     :death
                   else
                     self.counter += 1
                     :birth
                   end
    end
  end

  def output
  end

  def external_transition(bag)
  end
end

class Grapher
  include Quartz::Observer

  def initialize(model, @simulation : Quartz::Simulation)
    model.add_observer(self)
  end

  def update(model, info)
    if info && info[:transition] == :internal
      @simulation.generate_graph("dsde_#{info[:time].to_s}")
    end
  end
end

model = Quartz::DSDE::CoupledModel.new(:dsde, BirthController.new(:executive))

simulation = Quartz::Simulation.new(model, duration: Quartz.duration(25), maintain_hierarchy: true)
Quartz.set_debug_log_level
simulation.generate_graph("dsde_0")
Grapher.new(model.executive, simulation)
simulation.simulate
