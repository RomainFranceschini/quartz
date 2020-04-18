require "../src/quartz"

class NavigationModel < Quartz::AtomicModel
  state phase : Symbol = :change_course,
    bearing : Int16 = 90i16

  check :bearing, numericality: {gte: 0, lt: 360}

  def internal_transition
    self.bearing = -123i16
    self.phase = :idle
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
