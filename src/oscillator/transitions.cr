module DEVS
  # This mixin provides models with several transition methods
  # in line to the DEVS functions definition (δext, δint, δcon, λ and ta) and
  # the DEVS variables (σ, e, t).
  module Transitions

    @elapsed  : SimulationTime
    @sigma    : SimulationTime
    @time     : SimulationTime

    # This attribute is updated automatically along simulation and represents
    # the elapsed time since the last transition.
    property elapsed = 0.0

    # This attribute is updated along with simulation clock and
    # represent the last simulation time at which this model
    # was activated. Its default assigned value is -INFINITY.
    property time = -INFINITY

    # Sigma (σ) is a convenient variable introduced to simplify modeling phase
    # and represent the next activation time (see `#time_advance`)
    getter sigma = INFINITY


    # DEVS functions

    # The external transition function (δext)
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def external_transition(messages)
    #   messages.each { |port, value|
    #     puts "#{port} => #{value}"
    #   }
    #
    #   self.sigma = 0
    # end
    # ```
    def external_transition(messages : Hash(Port,Array(Any))); end

    # Internal transition function (δint), called when the model should be
    # activated, e.g when `#elapsed` reaches `#time_advance`
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def internal_transition; self.sigma = DEVS::INFINITY; end
    # ```
    def internal_transition; end

    # This is the default definition of the confluent transition. Here the
    # internal transition is allowed to occur and this is followed by the
    # effect of the external transition on the resulting state.
    #
    # Override this method to obtain a different behavior. For example, the
    # opposite order of effects (external transition before internal
    # transition). Of course you can override without reference to the other
    # transitions.
    def confluent_transition(messages : Hash(Port,Array(Any)))
      internal_transition
      external_transition(messages)
    end

    # Time advance function (ta), called after each transition to give a
    # chance to *self* to be active. By default returns `#sigma`
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def time_advance; self.sigma; end
    # ```
    def time_advance : SimulationTime
      @sigma
    end

    # The output function (λ)
    #
    # Override this method to implement the appropriate behavior of
    # your model. See `#post` to send values to output ports.
    #
    # Example:
    # ```
    # def output
    #   post(@some_value, :output)
    # end
    def output; end
  end
end
