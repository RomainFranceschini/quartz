module Quartz
  class RootCoordinator < Coordinator
    include Simulable

    @[AlwaysInline]
    def initialize_state(time)
      initialize_processor(time)
    end

    @[AlwaysInline]
    def step(time)
      perform_transitions(time, collect_outputs(time))
    end
  end
end
