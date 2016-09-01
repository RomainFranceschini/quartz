module Quartz
  # This class represent a simulator associated with an `CoupledModel`,
  # responsible to route events to proper children
  abstract class Coordinator < Processor#(CoupledModel)
    getter children

    # FIXME: temporarily use CalendarQueue(T) because EventSetType causes overload errors
    @scheduler : CalendarQueue(Processor) #EventSetType

    # Returns a new instance of Coordinator
    def initialize(model, @namespace : Symbol, scheduler : Symbol)
      super(model)
      @children = Array(Processor).new
      @scheduler = EventSetFactory(Processor).new_event_set(scheduler)
      @scheduler_type = scheduler
    end

    def inspect(io)
      io << "<" << self.class.name << "tn=" << @time_next.to_s(io)
      io << ", tl=" << @time_last.to_s(io)
      io << ", components=" << @children.size.to_s(io)
      io << ">"
      nil
    end

    # Append given *child* to `#children` list, ensuring that the child now has
    # *self* as parent.
    def <<(child : Processor)
      @children << child
      child.parent = self
      child
    end
    def add_child(child); self << child; end

    # Deletes the specified child from `#children` list
    def remove_child(child)
      @scheduler.delete(child)
      idx = @children.index { |x| child.equal?(x) }
      @children.delete_at(idx).parent = nil if idx
    end

    # Returns the minimum time next in all children
    def min_time_next
      @scheduler.next_priority
    end

    # Returns the maximum time last in all children
    def max_time_last
      max = 0
      i = 0
      while i < @children.size
        tl = @children[i].time_last
        max = tl if tl > max
        i += 1
      end
      max
    end
  end
end
