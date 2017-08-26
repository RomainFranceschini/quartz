module Quartz
  class RootCoordinator < Coordinator
    include Simulable

    @[AlwaysInline]
    def initialize_state(time)
      initialize_processor(time)
    end

    @[AlwaysInline]
    def step(time)
      collect_outputs(time)
      perform_transitions(time)
    end
  end
end
