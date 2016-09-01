module Quartz
  abstract class Simulator < Processor#(AtomicModel)

    def initialize(model)
      super(model)
      @transition_count = Hash(Symbol, UInt64).new { 0_u64 }
    end

    def transition_stats
      @transition_count
    end
  end
end
