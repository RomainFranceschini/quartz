module Quartz
  module Simulable
    abstract def initialize_state(time : SimulationTime) : SimulationTime
    abstract def step(time : SimulationTime) : SimulationTime
  end
end
