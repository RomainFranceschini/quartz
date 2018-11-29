require "../src/quartz"

class OneTimeModel < Quartz::AtomicModel
  @sigma = 20

  def external_transition(messages)
    puts "#{name} received #{messages}."
  end

  def internal_transition
    puts "#{name} does something."
    @sigma = Quartz::INFINITY
  end
end

class BirthController < Quartz::DSDE::Executive
  output :birth, :death, :add_coupling, :remove_coupling

  def initialize(name)
    super(name)
    @sigma = 1
    @counter = 0
    @reverse = false
  end

  def internal_transition
    if @reverse
      remove_coupling_from_network(:out, from: :in, between: "model_0", and: "model_#{@counter}")
      remove_model_from_network("model_#{@counter}")
      @counter -= 1
      @sigma = Quartz::INFINITY
    else
      add_model_to_network(OneTimeModel.new("model_#{@counter}"))
      add_coupling_to_network(:out, to: :in, between: "model_0", and: "model_#{@counter}") if @counter > 0
      if @counter == 2
        @reverse = true
      else
        @counter += 1
      end
      @sigma = 5
    end
  end
end

class Grapher
  include Quartz::Observer

  def initialize(model, @simulation : Quartz::Simulation)
    model.add_observer(self)
  end

  def update(model, info)
    if info && info[:transition] == :internal
      @simulation.generate_graph("dsde_#{@simulation.time.to_i}")
    end
  end
end

model = Quartz::DSDE::CoupledModel.new(:dsde, BirthController.new(:executive))

simulation = Quartz::Simulation.new(model, duration: 25)
simulation.generate_graph("dsde_0")
Grapher.new(model.executive, simulation)
simulation.simulate
