module Quartz
  class RootCoordinator < Coordinator
    include Simulable

    @[AlwaysInline]
    def initialize_state(time : TimePoint) : Duration
      initialize_processor(time)[1]
    end

    @[AlwaysInline]
    def step(time : TimePoint) : Duration
      planned = @event_set.imminent_duration.fixed
      collect_outputs(time)
      perform_transitions(time, planned)
    end
  end
end
