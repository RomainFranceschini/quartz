module Quartz
  module MultiComponent
    abstract struct ComponentState
    end

    abstract class Component < Model
      include Transitions
      include Observable

      property time_last : SimulationTime = 0
      property time_next : SimulationTime = 0

      getter influencers = Array(Component).new
      getter influencees = Array(Component).new

      # TODO: doc
      abstract def reaction_transition(states)

      # TODO: doc
      def output : Hash(Port, Any)?
      end

      # TODO: doc
      def internal_transition : Hash(Name, Any)?
      end

      # Event condition function (C), called only with an activity scanning
      # strategy, whenever the time elapses. If the event condition returns
      # true, the component is ready to be activated. By defaults returns
      # true.
      #
      # Override this method to implement the appropriate behavior of your
      # model.
      def event_condition
        true
      end
    end

  end
end
