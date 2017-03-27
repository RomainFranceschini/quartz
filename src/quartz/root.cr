module Quartz
  class RootCoordinator < Coordinator
    include Simulable

    @[AlwaysInline]
    def initialize_state(time)
      initialize_processor(time)
    end

    EMPTY_BAG = Hash(InPort, Array(Any)).new

    @[AlwaysInline]
    def step(time)
      collect_outputs(time)
      perform_transitions(time, EMPTY_BAG)
    end
  end
end
