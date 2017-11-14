module Quartz
  module Simulable
    abstract def initialize_state(time : VTime) : VTime
    abstract def step(time : VTime) : VTime
  end
end
