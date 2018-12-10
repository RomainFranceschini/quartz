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
      @time_cache = TimeCache(Processor).new(@event_set.current_time)
      @synchronize = Array(Processor).new
      @parent_bag = Hash(OutputPort, Array(Any)).new { |h, k|
        h[k] = Array(Any).new
      }
    end

    def inspect(io)
      io << "<" << self.class.name << "tn="
      @event_set.imminent_duration.to_s(io)
      io << ", components="
      @children.size.to_s(io)
      io << ">"
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
      @event_set.clear
      @time_cache.current_time = @event_set.current_time

      @event_set.advance until: time

      min_planned_duration = Duration::INFINITY
      max_elapsed = Duration.new(0)

      @children.each do |child|
        elapsed, planned_duration = child.initialize_processor(time)
        @time_cache.retain_event(child, elapsed)
        if !planned_duration.infinite?
          @event_set.plan_event(child, planned_duration)
        else
          child.planned_phase = planned_duration
        end
        min_planned_duration = planned_duration if planned_duration < min_planned_duration
        max_elapsed = elapsed if elapsed > max_elapsed
      end

      coupled = @model.as(CoupledModel)
      if coupled.count_observers > 0
        coupled.notify_observers(OBS_INFO_INIT_PHASE.merge({:time => time}))
      end

      {max_elapsed.fixed, min_planned_duration.fixed}
    end

    def collect_outputs(elapsed : Duration)
      @event_set.advance by: elapsed

      coupled = @model.as(CoupledModel)
      @parent_bag.clear unless @parent_bag.empty?

      @event_set.each_imminent_event do |child|
        output = child.collect_outputs(elapsed)

        output.each do |port, payload|
          if child.is_a?(Simulator) && port.count_observers > 0
            port.notify_observers({
              :payload => payload.as(Any),
              :time    => @event_set.current_time,
              :elapsed => elapsed,
            })
          end

          # check internal coupling to get children who receive sub-bag of y
          coupled.each_internal_coupling(port) do |_, dst|
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
          coupled.each_output_coupling(port) do |_, dst|
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

      if coupled.count_observers > 0
        coupled.notify_observers(OBS_INFO_COLLECT_PHASE.merge({
          :time    => @event_set.current_time,
          :elapsed => elapsed,
        }))
      end

      @parent_bag
    end

    def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
      self.handle_external_inputs(time)

      @synchronize.each do |receiver|
        perform_transition_for(receiver, time)
      end

      bag.clear
      @synchronize.clear

      coupled = @model.as(CoupledModel)
      if coupled.count_observers > 0
        coupled.notify_observers(OBS_INFO_TRANSITIONS_PHASE.merge({
          :time    => time,
          :elapsed => elapsed,
        }))
      end

      @event_set.imminent_duration.fixed
    end

    protected def handle_external_inputs(time : TimePoint)
      bag = @bag || EMPTY_BAG

      if @event_set.current_time < time && !bag.empty?
        @event_set.advance until: time
      end

      bag.each do |port, sub_bag|
        # check external input couplings to get children who receive sub-bag of y
        @model.as(CoupledModel).each_input_coupling(port) do |_, dst|
          receiver = dst.host.processor

          if !receiver.sync
            @synchronize << receiver
            receiver.sync = true
          end

          receiver.bag[dst].concat(sub_bag)
        end
      end
    end

    protected def perform_transition_for(receiver : Processor, time : TimePoint)
      receiver.sync = false
      elapsed_duration = @time_cache.elapsed_duration_of(receiver)

      remaining_duration = @event_set.duration_of(receiver)

      # before trying to cancel a receiver, test if time is not strictly
      # equal to its time_next. If true, it means that its model will
      # receiver either an internal transition or a confluent transition,
      # and that the receiver is no longer in the scheduler.
      ev_deleted = if remaining_duration.zero?
                     elapsed_duration = Duration.zero(elapsed_duration.precision, elapsed_duration.fixed?)
                     true
                   elsif !remaining_duration.infinite?
                     # Priority queues with an event invalidation strategy may return
                     # nil when trying to cancel a specific event.
                     # For example, the ladder queue might successfully delete an event if
                     # it is stored in the ladder tier, but not always.
                     @event_set.cancel_event(receiver) != nil
                   else
                     true
                   end

      planned_duration = receiver.perform_transitions(time, elapsed_duration)

      # No need to reschedule the event if its planned duration is infinite.
      if planned_duration.infinite?
        receiver.planned_phase = Duration::INFINITY.fixed
      else
        # If a ta(s)=0 occured and the event was not properly deleted,
        # we don't need to reschedule it. This check is done for priority
        # queues with invalidation strategy.
        if ev_deleted || (!ev_deleted && !planned_duration.zero?)
          @event_set.plan_event(receiver, planned_duration)
        end
      end

      @time_cache.retain_event(receiver, planned_duration.precision)
    end
  end
end
