require "../src/quartz"

class NavigationModel < Quartz::AtomicModel
  state_var bearing : Int16 = 90i16
  check :bearing, numericality: {gte: 0, lt: 360}

  @sigma = Quartz.duration(1)

  def internal_transition
    @bearing = -123i16
    @sigma = Quartz::Duration::INFINITY
  end
end

sim = Quartz::Simulation.new(NavigationModel.new("nav"), run_validations: true)
sim.simulate
