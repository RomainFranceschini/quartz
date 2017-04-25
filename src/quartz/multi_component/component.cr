module Quartz
  module MultiComponent
    abstract class Component < Model
      include Transitions
      include Observable
      include Validations
      include AutoState

      property time_last : SimulationTime = 0
      property time_next : SimulationTime = 0

      getter influencers = Array(Component).new
      getter influencees = Array(Component).new

      def initialize(name)
        super(name)
      end

      def initialize(name, state)
        super(name)
        self.initial_state = state
        self.state = state
      end

      # Used internally by the simulator
      # :nodoc:
      def __initialize_state__(processor)
        if @processor != processor
          raise InvalidProcessorError.new("trying to initialize state of model \"#{name}\" from an invalid processor")
        end

        if s = initial_state
          self.state = s
        end
      end

      # TODO: doc
      abstract def reaction_transition(states)

      # TODO: doc
      def output : SimpleHash(Port, Any)?
      end

      # TODO: doc
      def internal_transition : SimpleHash(Name, Any)?
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
