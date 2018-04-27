module Quartz
  # This class represent a simulator associated with an `CoupledModel`,
  # responsible to route events to proper children
  class Coordinator < Processor
    getter children

    @event_set : EventSet(Processor)
    @time_cache : TimeCache(Processor)

    # Returns a new instance of Coordinator
    def initialize(model : Model, simulation : Simulation)
      super(model)

      @children = Array(Processor).new
      priority_queue = model.class.preferred_event_set? || simulation.default_scheduler
      @event_set = EventSet(Processor).new(priority_queue)
      @time_cache = TimeCache(Processor).new(priority_queue)
      @synchronize = Array(Processor).new
      @parent_bag = Hash(OutputPort, Array(Any)).new { |h, k|
        h[k] = Array(Any).new
      }
    end

    def inspect(io)
      io << "<" << self.class.name << "tn=" << @event_set.imminent_duration.to_s(io)
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

    def add_child(child)
      self << child
    end

    # Deletes the specified child from `#children` list
    def remove_child(child)
      @event_set.delete(child)
      idx = @children.index { |x| child.equal?(x) }
      @children.delete_at(idx).parent = nil if idx
    end

    def initialize_processor(time : TimePoint) : {Duration, Duration}
      @event_set.advance until: time
      @time_cache.advance until: time

      min_planned_duration = Duration::INFINITY
      max_elapsed = Duration.new(0)
      selected = Array(Processor).new

      @event_set.clear

      @children.each do |child|
        elapsed, planned_duration = child.initialize_processor(time)
        @time_cache.retain_event(child, elapsed)
        # selected.push(child) if !planned_duration.infinite?
        if !planned_duration.infinite?
          @event_set.plan_event(child, planned_duration)
        end
        min_planned_duration = planned_duration if planned_duration < min_planned_duration
        max_elapsed = elapsed if elapsed > max_elapsed
      end

      # list = @event_set.priority_queue.is_a?(ReschedulePriorityQueue) ? @children : selected
      # list = @children
      # list.each { |duration, child| @event_set.plan_event(child, duration) }

      @model.as(CoupledModel).notify_observers(OBS_INFO_INIT_PHASE)

      {max_elapsed, min_planned_duration}
    end

    def collect_outputs(time : TimePoint)
      @event_set.advance until: time
      @time_cache.advance until: time

      coupled = @model.as(CoupledModel)
      @parent_bag.clear unless @parent_bag.empty?

      @event_set.each_imminent_event do |child|
        output = child.collect_outputs(time)

        output.each do |port, payload|
          if child.is_a?(Simulator) && port.count_observers > 0
            port.notify_observers({:payload => payload.as(Any)})
          end

          # check internal coupling to get children who receive sub-bag of y
          coupled.each_internal_coupling(port) do |src, dst|
            receiver = dst.host.processor

            if !receiver.sync
              @synchronize << receiver
              receiver.sync = true
            end

            if child.is_a?(Coordinator)
              receiver.bag[dst].concat(payload.as(Array(Any)))
            else
              receiver.bag[dst] << payload.as(Any)
            end
          end

          # check external coupling to form sub-bag of parent output
          coupled.each_output_coupling(port) do |src, dst|
            if child.is_a?(Coordinator)
              @parent_bag[dst].concat(payload.as(Array(Any)))
            else
              @parent_bag[dst] << (payload.as(Any))
            end
          end
        end

        if !child.sync
          child.sync = true
          @synchronize << child.as(Processor)
        end
      end

      coupled.notify_observers(OBS_INFO_COLLECT_PHASE)

      @parent_bag
    end

    def perform_transitions(planned : Duration, elapsed : Duration) : Duration
      bag = @bag || EMPTY_BAG

      bag.each do |port, sub_bag|
        # check external input couplings to get children who receive sub-bag of y
        @model.as(CoupledModel).each_input_coupling(port) do |src, dst|
          receiver = dst.host.processor

          if !receiver.sync
            @synchronize << receiver
            receiver.sync = true
          end

          receiver.bag[dst].concat(sub_bag)
        end
      end

      @synchronize.each do |receiver|
        receiver.sync = false
        elapsed_duration = @time_cache.elapsed_duration_of(receiver)

        # if @event_set.priority_queue.is_a?(ReschedulePriorityQueue)
        #   new_planned_duration = receiver.perform_transitions(time, elapsed_duration)
        #   receiver.planned_phase = @event_set.phase_from_duration(new_planned_duration)
        # elsif @event_set.priority_queue.is_a?(LadderQueue)
        #   # Special case for the ladder queue

        #   planned_duration = @event_set.duration_from_phase(receiver.planned_duration)
        #   # Before trying to cancel a receiver, test if time is not strictly
        #   # equal to its tn. If true, it means that its model will
        #   # receiver either an internal transition or a confluent transition,
        #   # and that the receiver is no longer in the scheduler.
        #   is_in_scheduler = !planned_duration.infinite? && duration != planned_duration
        #   if is_in_scheduler
        #     # The ladder queue might successfully delete the event if it is
        #     # stored in the *ladder* tier, but is allowed to return nil since
        #     # deletion strategy is based on event invalidation.
        #     if @event_set.delete(receiver)
        #       is_in_scheduler = false
        #     end
        #   end
        #   new_planned_duration = receiver.perform_transitions(elapsed_duration, duration)

        #   # No need to reschedule the event if its tn is equal to INFINITY.
        #   # If a ta(s)=0 occured and that the old event is still present in
        #   # the ladder queue, we don't need to reschedule it either.
        #   if new_planned_duration < Duration::INFINITY && (!is_in_scheduler || (new_planned_duration > tn && is_in_scheduler))
        #     @event_set.plan_duration(receiver, new_planned_duration)
        #   end
        # else
        planned_duration = @event_set.duration_of(receiver)
        # before trying to cancel a receiver, test if time is not strictly
        # equal to its time_next. If true, it means that its model will
        # receiver either an internal transition or a confluent transition,
        # and that the receiver is no longer in the scheduler.
        if !planned_duration.infinite? && planned_duration > elapsed_duration
          @event_set.cancel_event(receiver)
        end

        planned_duration = receiver.perform_transitions(planned, elapsed_duration)
        if !planned_duration.infinite?
          @event_set.plan_event(receiver, planned_duration)
        end
      end

      # @event_set.reschedule! if @event_set.is_a?(ReschedulePriorityQueue)
      bag.each_value &.clear
      @synchronize.clear

      @model.as(CoupledModel).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

      @event_set.imminent_duration
    end
  end
end
