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

    include Logging

    getter model : Model
    property sync : Bool
    property parent : Coordinator?

    @bag : Hash(InputPort, Array(Any))?

    def initialize(@model : Model)
      @sync = false
      @model.processor = self
    end

    def bag
      @bag ||= Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
    end

    def bag?
      @bag
    end

    # def inspect(io)
    #   io << "<" << self.class.name << ": "
    #   io << "planned_duration=" << @event_set.duration_from_phase(@planned_phase).to_s(io)
    #   io << ", elapsed=" << @time_cache.elapsed_duration_of(self).to_s(io) << ">"
    #   nil
    # end

    abstract def initialize_processor(time : TimePoint) : {Duration, Duration}
    abstract def collect_outputs(elapsed : Duration) : Hash(OutputPort, Any)
    abstract def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
  end
end
