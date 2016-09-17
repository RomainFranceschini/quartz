module Quartz
  module DSDE
    class RootCoordinator < Coordinator
      include Simulable

      def initialize_state(time)
        initialize_processor(time)
      end

      def step(time)
        perform_transitions(time, collect_outputs(time))
      end
    end
  end
end
