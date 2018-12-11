module Quartz
  class RootCoordinator < Coordinator
    include Simulable

    delegate current_time, to: @event_set

    @[AlwaysInline]
    def initialize_state(time : TimePoint) : Duration
      initialize_processor(time)[1]
    end

    @[AlwaysInline]
    def step(elapsed : Duration) : Duration
      collect_outputs(elapsed)
      perform_transitions(current_time, elapsed)
    end
  end
end
