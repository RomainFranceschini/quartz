module Quartz
  module MultiComponent
    abstract class Component < Model
      include Transitions
      include Schedulable
      include Observable
      include Verifiable
      include AutoState

      getter influencers = Array(Component).new
      getter influencees = Array(Component).new

      # The precision associated with the model.
      getter precision : Scale = Scale::BASE

      def precision=(@precision : Scale)
        @elapsed = @elapsed.rescale(@precision)
        @sigma = @sigma.rescale(@precision)
      end

      # This attribute is updated automatically along simulation and represents
      # the elapsed time since the last transition.
      property elapsed : Duration = Duration.zero

      # Sigma (σ) is a convenient variable introduced to simplify modeling phase
      # and represent the next activation time (see `#time_advance`)
      getter sigma : Duration = Duration::INFINITY

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
        @elapsed = @elapsed.rescale(@precision)
        @sigma = @sigma.rescale(@precision)
      end

      def initialize(name, state)
        super(name)
        @elapsed = @elapsed.rescale(@precision)
        @sigma = @sigma.rescale(@precision)
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
