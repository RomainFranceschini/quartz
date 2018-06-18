module Quartz
  module Simulable
    abstract def initialize_state(time : TimePoint) : Duration
    abstract def step(elapsed : Duration) : Duration
  end
end
