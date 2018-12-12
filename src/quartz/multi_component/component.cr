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
      class_property precision : Scale = Scale::BASE

      # Defines the precision level associated to this class of models.
      #
      # ### Usage:
      #
      # `precision` must receive a scale unit. The scale unit can be specified
      # with a constant expression (e.g. 'kilo'), with a `Scale` struct or with
      # a number literal.
      #
      # ```
      # precision Scale.::KILO
      # precision -8
      # precision femto
      # ```
      #
      # If specified with a constant expression, the unit argument can be a string
      # literal, a symbol literal or a plain name.
      #
      # ```
      # precision kilo
      # precision "kilo"
      # precision :kilo
      # ```
      #
      # ### Example
      #
      # ```
      # class MyModel < Quartz::AtomicModel
      #   precision femto
      # end
      # ```
      #
      # Is the same as writing:
      #
      # ```
      # class MyModel < Quartz::AtomicModel
      #   self.precision = Scale::FEMTO
      # end
      # ```
      #
      # Or the same as:
      #
      # ```
      # class MyModel < Quartz::AtomicModel; end
      #
      # MyModel.precision = Scale::FEMTO
      # ```
      macro precision(scale = "base")
      {% if Quartz::ALLOWED_SCALE_UNITS.includes?(scale.id.stringify) %}
        self.precision = Quartz::Scale::{{ scale.id.upcase }}
      {% elsif scale.is_a?(NumberLiteral) %}
        self.precision = Quartz::Scale.new({{scale}})
      {% else %}
        self.precision = {{scale}}
      {% end %}
    end

      # Returns the precision associated with the class.
      def model_precision : Scale
        @@precision
      end

      # This attribute is updated automatically along simulation and represents
      # the elapsed time since the last transition.
      property elapsed : Duration = Duration.zero(@@precision)

      # Sigma (σ) is a convenient variable introduced to simplify modeling phase
      # and represent the next activation time (see `#time_advance`)
      getter sigma : Duration = Duration.infinity(@@precision)

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
        @elapsed = @elapsed.rescale(@@precision)
        @sigma = @sigma.rescale(@@precision)
      end

      def initialize(name, state)
        super(name)
        @elapsed = @elapsed.rescale(@@precision)
        @sigma = @sigma.rescale(@@precision)
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
