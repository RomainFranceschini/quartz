module Quartz
  module Simulable
    abstract def current_time : TimePoint
    abstract def advance(by elapsed : Duration)
    abstract def initialize_state(time : TimePoint) : Duration
    abstract def step(elapsed : Duration) : Duration
  end
end
