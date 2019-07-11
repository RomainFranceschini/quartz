module Quartz
  abstract class Processor
    include Schedulable

    # :nodoc:
    OBS_INFO_INIT_PHASE = {:phase => Any.new(:init)}
    # :nodoc:
    OBS_INFO_COLLECT_PHASE = {:phase => Any.new(:collect_outputs)}
    # :nodoc:
    OBS_INFO_TRANSITIONS_PHASE = {:phase => Any.new(:perform_transitions)}
    # :nodoc:
    EMPTY_BAG = Hash(InputPort, Array(Any)).new

    # :nodoc:
    OBS_INFO_INIT_TRANSITION = {:transition => Any.new(:init)}
    # :nodoc:
    OBS_INFO_INT_TRANSITION = {:transition => Any.new(:internal)}
    # :nodoc:
    OBS_INFO_EXT_TRANSITION = {:transition => Any.new(:external)}
    # :nodoc:
    OBS_INFO_CON_TRANSITION = {:transition => Any.new(:confluent)}

    getter model : Model
    property sync : Bool
    property parent : Coordinator?

    @bag : Hash(InputPort, Array(Any))?

    def initialize(@model : Model)
      @sync = false
      @model.processor = self
    end

    def bag : Hash(InputPort, Array(Any))
      @bag ||= Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
    end

    def bag? : Hash(InputPort, Array(Any))?
      @bag
    end

    def to_s(io)
      io << self.class.name << "("
      @model.to_s(io)
      io << ")"
    end

    def inspect(io)
      io << "<" << self.class.name << ": model="
      @model.to_s(io)

      io << " planned_phase="
      self.planned_phase.to_s(io)
      io << " imag_phase="
      self.imaginary_phase.to_s(io)
      io << ">"
    end

    abstract def initialize_processor(time : TimePoint) : {Duration, Duration}
    abstract def collect_outputs(elapsed : Duration) : Hash(OutputPort, Any)
    abstract def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
  end
end
