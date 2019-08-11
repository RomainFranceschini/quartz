module Quartz
  # This class represent a simulator associated with an `CoupledModel`,
  # responsible to route events to proper children
  class Coordinator < Processor
    include Schedulable

    getter children

    @event_set : EventSet
    @time_cache : TimeCache

    # Returns a new instance of Coordinator
    def initialize(model : Model, simulation : Simulation)
      super(model)

      @children = Array(Processor).new
      priority_queue = model.class.preferred_event_set? || simulation.default_scheduler
      @event_set = EventSet.new(priority_queue, simulation.virtual_time)
      @time_cache = TimeCache.new(simulation.virtual_time)
      @synchronize = Array(Schedulable).new
      @parent_bag = Hash(OutputPort, Array(Any)).new { |h, k|
        h[k] = Array(Any).new
      }
      @time_bases = {} of Duration => TimeBase
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
      @time_cache.current_time = @event_set.current_time = time

      min_planned_duration = Duration::INFINITY
      max_elapsed = Duration.new(0)

      @children.each do |child|
        if child.is_a?(DTSS::Simulator)
          delta_t = child.model.as(DTSS::AtomicModel).time_delta
          time_base = @time_bases[delta_t] ||= TimeBase.new(delta_t)
          time_base.processors << child
          child.initialize_processor(time)
        elsif child.is_a?(Schedulable)
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
      end

      @time_bases.each_value do |time_base|
        @time_cache.retain_event(time_base, Duration.zero(time_base.time_next.precision))
        @event_set.plan_event(time_base, time_base.time_next)
        min_planned_duration = time_base.time_next if time_base.time_next < min_planned_duration
      end

      coupled = @model.as(CoupledModel)
      if coupled.count_observers > 0
        coupled.notify_observers(OBS_INFO_INIT_PHASE.merge({:time => time}))
      end

      {max_elapsed.fixed, min_planned_duration.fixed}
    end

    def collect_outputs(elapsed : Duration) : Hash(OutputPort, Array(Any))
      @parent_bag.clear unless @parent_bag.empty?

      @event_set.each_imminent_event do |child|
        if child.is_a?(TimeBase)
          raise BadSynchronisationError.new if child.time_next != elapsed

          child.processors.each do |processor|
            output = processor.collect_outputs(elapsed)
            route_outputs(processor, output, elapsed)
          end

          @synchronize << child
        elsif child.is_a?(Processor)
          output = child.collect_outputs(elapsed)
          route_outputs(child, output, elapsed)
        end
      end

      if @model.as(CoupledModel).count_observers > 0
        @model.as(CoupledModel).notify_observers(OBS_INFO_COLLECT_PHASE.merge({
          :time    => @event_set.current_time,
          :elapsed => elapsed,
        }))
      end

      @parent_bag
    end

    private def route_outputs(child : Processor, output : Hash(OutputPort, Array(Any)), elapsed : Duration)
      coupled = @model.as(CoupledModel)
      output.each do |port, payload|
        if !child.is_a?(CoupledModel) && port.count_observers > 0
          port.notify_observers({
            :payload => payload,
            :time    => @event_set.current_time,
            :elapsed => elapsed,
          })
        end

        # check internal coupling to get children who receive sub-bag of y
        coupled.each_internal_coupling(port) do |src, dst|
          receiver = dst.host.processor

          if !receiver.is_a?(DTSS::Simulator) && !receiver.sync
            @synchronize << receiver.as(Schedulable)
            receiver.sync = true
          end

          ary_payload = payload.as(Array(Any))
          dst_payload = if coupled.has_transducer_for?(src, dst)
                          coupled.transducer_for(src, dst).call(ary_payload.as(Enumerable(Any)))
                        else
                          ary_payload
                        end
          receiver.bag[dst].concat(dst_payload)
        end

        # check external coupling to form sub-bag of parent output
        coupled.each_output_coupling(port) do |src, dst|
          ary_payload = payload.as(Array(Any))
          dst_payload = if coupled.has_transducer_for?(src, dst)
                          coupled.transducer_for(src, dst).call(ary_payload.as(Enumerable(Any)))
                        else
                          ary_payload
                        end

          @parent_bag[dst].concat(dst_payload)
        end
      end

      if !child.is_a?(DTSS::Simulator) && !child.sync
        child.sync = true
        @synchronize << child.as(Schedulable)
      end
    end

    def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
      self.handle_external_inputs(time)

      @synchronize.each do |receiver|
        perform_transition_for(receiver.as(Processor | TimeBase), time)
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
      coupled = @model.as(CoupledModel)

      bag.each do |port, sub_bag|
        # check external input couplings to get children who receive sub-bag of y
        coupled.each_input_coupling(port) do |src, dst|
          receiver = dst.host.processor

          if !receiver.is_a?(DTSS::Simulator) && !receiver.sync
            @synchronize << receiver.as(Schedulable)
            receiver.sync = true
          end

          dst_sub_bag = if coupled.has_transducer_for?(src, dst)
                          coupled.transducer_for(src, dst).call(sub_bag.as(Enumerable(Any)))
                        else
                          sub_bag
                        end

          receiver.bag[dst].concat(dst_sub_bag)
        end
      end
    end

    protected def perform_transition_for(time_base : TimeBase, time : TimePoint)
      elapsed_duration = @time_cache.elapsed_duration_of(time_base.as(Schedulable))
      remaining_duration = @event_set.duration_of(time_base.as(Schedulable))
      planned_duration = time_base.time_next

      time_base.processors.each do |receiver|
        receiver.perform_transitions(time, elapsed_duration, true)
      end

      @event_set.plan_event(time_base.as(Schedulable), planned_duration)
      @time_cache.retain_event(time_base.as(Schedulable), planned_duration.precision)
    end

    protected def perform_transition_for(receiver : Processor, time : TimePoint)
      receiver.sync = false
      elapsed_duration = @time_cache.elapsed_duration_of(receiver.as(Schedulable))

      remaining_duration = @event_set.duration_of(receiver.as(Schedulable))

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
                     @event_set.cancel_event(receiver.as(Schedulable)) != nil
                   else
                     true
                   end

      planned_duration = case receiver
                         when Simulator
                           receiver.perform_transitions(time, elapsed_duration, remaining_duration.zero?)
                         else
                           receiver.perform_transitions(time, elapsed_duration)
                         end

      # No need to reschedule the event if its planned duration is infinite.
      if planned_duration.infinite?
        receiver.as(Schedulable).planned_phase = Duration::INFINITY.fixed
      else
        # If a ta(s)=0 occured and the event was not properly deleted,
        # we don't need to reschedule it. This check is done for priority
        # queues with invalidation strategy.
        if ev_deleted || (!ev_deleted && !planned_duration.zero?)
          @event_set.plan_event(receiver.as(Schedulable), planned_duration)
        end
      end

      @time_cache.retain_event(receiver.as(Schedulable), planned_duration.precision)
    end
  end
end
