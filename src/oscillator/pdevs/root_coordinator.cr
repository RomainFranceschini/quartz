module DEVS
  module PDEVS
    class RootCoordinator < PDEVS::Coordinator
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
