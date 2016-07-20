module DEVS
  # This class represent a simulator associated with an {CoupledModel},
  # responsible to route events to proper children
  abstract class Coordinator < Processor#(CoupledModel)
    getter children

    @scheduler : EventSetType

    # Returns a new instance of Coordinator
    def initialize(model, @namespace : Symbol, scheduler : Symbol)
      super(model)
      @children = Array(Processor).new
      @scheduler = case scheduler
      when :ladder_queue then LadderQueue(Processor).new
      when :binary_heap then BinaryHeap(Processor).new
      when :minimal_list then MinimalList(Processor).new
      when :sorted_list then SortedList(Processor).new
      when :splay_tree then SplayTree(Processor).new
      when :calendar_queue then CalendarQueue(Processor).new
      else
        #DEVS.logger.warn("scheduler #{@opts[:scheduler]} unknown, defaults to LadderQueue") if DEVS.logger
        #LadderQueue(Processor)
        CalendarQueue(Processor).new
      end
      @scheduler_type = scheduler
    end

    def inspect
      "<#{self.class}: tn=#{@time_next}, tl=#{@time_last}, components=#{@children.size}>"
    end

    # Append given *child* to `#children` list, ensuring that the child now has
    # *self* as parent.
    def <<(child : Processor)
      @children << child
      child.parent = self
      child
    end
    def add_child(child); self << child; end

    # Deletes the specified child from {#children} list
    #
    # @param child [Processor] the child to remove
    # @return [Processor] the deleted child
    def remove_child(child)
      @scheduler.delete(child)
      idx = @children.index { |x| child.equal?(x) }
      @children.delete_at(idx).parent = nil if idx
    end

    # Returns the minimum time next in all children
    #
    # @return [Numeric] the min time next
    def min_time_next
      @scheduler.next_priority
    end

    # Returns the maximum time last in all children
    #
    # @return [Numeric] the max time last
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
