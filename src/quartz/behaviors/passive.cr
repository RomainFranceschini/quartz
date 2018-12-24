module Quartz
  # This mixin provides a passive behavior to the included `AtomicModel`.
  module PassiveBehavior
    def external_transition(messages : Hash(InputPort, Array(Any)))
    end

    def internal_transition
    end

    def time_advance : Duration
      Quartz::Duration.infinity(model_precision)
    end

    def output
    end
  end
end
