module Quartz
  abstract class Processor # (T)

    # :nodoc:
    OBS_INFO_INIT_PHASE = { :phase => Any.new(:init) }
    # :nodoc:
    OBS_INFO_COLLECT_PHASE = { :phase => Any.new(:collect_outputs) }
    # :nodoc:
    OBS_INFO_TRANSITIONS_PHASE = { :phase => Any.new(:perform_transitions) }

    include Logging
    # include Comparable(self)

    getter model : Model
    getter time_next : SimulationTime
    getter time_last : SimulationTime
    property sync : Bool
    property parent : Coordinator?

    def initialize(@model : Model)
      @time_next = 0
      @time_last = 0
      @sync = false
      @model.processor = self
    end

    # The comparison operator. Compares two processors given their #time_next
    #
    # @param other [Processor]
    # @return [Integer]
    # def <=>(other)
    #   other.time_next <=> @time_next
    # end

    def inspect(io)
      io << "<" << self.class.name << ": tn=" << @time_next.to_s(io)
      io << ", tl=" << @time_last.to_s(io) << ">"
      nil
    end

    abstract def collect_outputs(time) : Hash(OutputPort, Any)
    abstract def perform_transitions(time, bag : Hash(InputPort, Array(Any))) : SimulationTime
  end
end
