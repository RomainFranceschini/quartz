require "../src/quartz"

class NavigationModel < Quartz::AtomicModel
  state_var phase : Symbol = :change_course
  state_var bearing : Int16 = 90i16
  check :bearing, numericality: {gte: 0, lt: 360}

  def internal_transition
    @bearing = -123i16
    @phase = :idle
  end

  def external_transition(bag)
  end

  def output
  end

  def time_advance : Quartz::Duration
    case phase
    when :change_course then Quartz.duration(1)
    else                     Quartz::Duration::INFINITY
    end
  end
end

sim = Quartz::Simulation.new(NavigationModel.new("nav"), run_validations: true)
sim.simulate
