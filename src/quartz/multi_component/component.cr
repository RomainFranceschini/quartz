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

      @__parent__ : MultiComponent::Model?
      def __parent__=(parent : MultiComponent::Model)
        @__parent__ = parent
      end

      def input_port(port)
        @__parent__.not_nil!.input_port(port)
      end

      def output_port(port)
        @__parent__.not_nil!.output_port(port)
      end

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
    end
  end
end
