module Quartz
  module MultiComponent
    abstract class Component < Model
      include Schedulable
      include Observable
      include Verifiable
      include Stateful

      getter influencers = Array(Component).new
      getter influencees = Array(Component).new

      # The precision associated with the model.
      class_property precision_level : Scale = Scale::BASE

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
        self.precision_level = Quartz::Scale::{{ scale.id.upcase }}
      {% elsif scale.is_a?(NumberLiteral) %}
        self.precision_level = Quartz::Scale.new({{scale}})
      {% else %}
        self.precision_level = {{scale}}
      {% end %}
      end

      # Returns the precision associated with the class.
      def model_precision : Scale
        @@precision_level
      end

      # This attribute is updated automatically along simulation and represents
      # the elapsed time since the last transition.
      property elapsed : Duration = Duration.zero(@@precision_level)

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
        @elapsed = @elapsed.rescale(@@precision_level)
      end

      def initialize(name, state)
        super(name)
        @elapsed = @elapsed.rescale(@@precision_level)
        self.initial_state = state.clone
        self.state = state
      end

      # Used internally by the simulator
      # :nodoc:
      def __initialize_state__(processor)
        if @processor != processor
          raise InvalidProcessorError.new("trying to initialize state of model \"#{name}\" from an invalid processor")
        end

        if s = initial_state
          equals = s == self.state
          if !equals || (equals && s.same?(self.state))
            self.state = s.clone
          end
        end
      end

      # Internal transition function (δint), called when the model should be
      # activated, e.g when `#elapsed` reaches `#time_advance`
      #
      # Override this method to implement the appropriate behavior of
      # your model.
      abstract def internal_transition : Hash(Name, Any)?

      # This is the default definition of the confluent transition. Here the
      # internal transition is allowed to occur and this is followed by the
      # effect of the external transition on the resulting state.
      #
      # Override this method to obtain a different behavior. For example, the
      # opposite order of effects (external transition before internal
      # transition). Of course you can override without reference to the other
      # transitions.
      def confluent_transition(messages : Hash(InputPort, Array(Any))) : Hash(Name, Any)?
        states = internal_transition
        if self.responds_to?(:external_transition)
          if states2 = external_transition(messages)
            states2.each do |key, val|
              states[key] = val
            end
          end
        end
        states
      end

      # Time advance function (ta), called after each transition to give a
      # chance to *self* to be active.
      #
      # Override this method to implement the appropriate behavior of
      # your model.
      #
      # Example:
      # ```
      # def time_advance
      #   Quartz.infinity
      # end
      # ```
      abstract def time_advance : Duration

      # TODO: doc
      abstract def reaction_transition(states)
    end
  end
end
