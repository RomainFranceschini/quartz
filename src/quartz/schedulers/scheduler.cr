module Quartz
  abstract class PriorityQueue(T)
    abstract def size : Int
    abstract def empty? : Bool
    abstract def clear
    abstract def push(value : T)

    def <<(value : T)
      self.push(value)
    end

    abstract def peek : T
    abstract def peek? : T?
    abstract def pop : T
    abstract def delete(value : T) : T
  end

  alias Priority = SimulationTime

  # compiler problem in 0.16.0 with generics (see #2558)
  module EventSetType; end

  # Try with 0.19
  # module Schedulable
  #   abstract def time_next : SimulationTime
  # end

  abstract class EventSet(T) < PriorityQueue(T)
    include EventSetType

    def next_priority : Priority
      if el = peek?
        el.time_next
      else
        Quartz::INFINITY
      end
    end

    def delete_all(priority : Priority) : Array(T)
      ary = [] of T
      while !self.empty? && self.next_priority == priority
        ary << self.pop
      end
      ary
    end

    def peek_all(priority : Priority) : Array(T)
      raise Exception.new("Not implemented.")
    end

    def reschedule!
      raise Exception.new("Not implemented.")
    end
  end

  abstract class RescheduleEventSet(T) < EventSet(T)
    #abstract def reschedule!;
    #abstract def peek_all(priority : Priority) : Array(T)
  end
end
