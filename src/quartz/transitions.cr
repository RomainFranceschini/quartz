module Quartz
  # This mixin provides models with several transition methods
  # in line to the PDEVS functions definition (δext, δint, δcon, λ and ta).
  module Transitions
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
    def external_transition(messages : Hash(InputPort, Array(Any))); end

    # Internal transition function (δint), called when the model should be
    # activated, e.g when `#elapsed` reaches `#time_advance`
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def internal_transition
    #   self.sigma = Quartz::INFINITY
    # end
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
    def confluent_transition(messages : Hash(InputPort, Array(Any)))
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
    # def time_advance
    #   self.sigma
    # end
    # ```
    def time_advance : Duration
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
