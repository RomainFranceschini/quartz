module Quartz
  # This class represent a simulator associated with an `CoupledModel`,
  # responsible to route events to proper children
  class Coordinator < Processor
    getter children

    @scheduler : EventSet(Processor)

    # Returns a new instance of Coordinator
    def initialize(model : Model, simulation : Simulation)
      super(model)

      @children = Array(Processor).new
      scheduler_type = model.class.preferred_event_set? || simulation.default_scheduler
      @scheduler = EventSetFactory(Processor).new_event_set(scheduler_type)
      @synchronize = Array(SyncEntry).new
      @parent_bag = Hash(OutputPort, Array(Any)).new { |h, k|
        h[k] = Array(Any).new
      }
    end

    struct SyncEntry
      getter processor : Processor
      getter bag : Hash(InputPort, Array(Any))?

      def initialize(@processor, @bag = nil)
      end
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

    def add_child(child)
      self << child
    end

    # Deletes the specified child from `#children` list
    def remove_child(child)
      @scheduler.delete(child)
      idx = @children.index { |x| child.equal?(x) }
      @children.delete_at(idx).parent = nil if idx
    end

    # Returns the minimum time next in all children
    protected def min_time_next
      @scheduler.next_priority
    end

    # Returns the maximum time last in all children
    protected def max_time_last
      @children.reduce(-INFINITY) { |memo, child| Math.max(memo, child.time_last) }
    end

    def initialize_processor(time)
      min = Quartz::INFINITY
      selected = Array(Processor).new

      @children.each do |child|
        tn = child.initialize_processor(time)
        selected.push(child) if tn < Quartz::INFINITY
        min = tn if tn < min
      end

      @scheduler.clear
      list = @scheduler.is_a?(RescheduleEventSet) ? @children : selected
      list.each { |c| @scheduler << c }

      @model.as(CoupledModel).notify_observers(OBS_INFO_INIT_PHASE)

      @time_last = max_time_last
      @time_next = min
    end

    def collect_outputs(time)
      if time != @time_next
        raise BadSynchronisationError.new("\ttime: #{time} should match time_next: #{@time_next}")
      end
      @time_last = time

      coupled = @model.as(CoupledModel)
      @parent_bag.clear unless @parent_bag.empty?

      @scheduler.each_imminent(time) do |child|
        output = child.collect_outputs(time)

        output.each do |port, payload|
          if child.is_a?(Simulator) && port.count_observers > 0
            port.notify_observers({:payload => payload.as(Any)})
          end

          # check internal coupling to get children who receive sub-bag of y
          coupled.each_internal_coupling(port) do |src, dst|
            receiver = dst.host.processor

            entry = if receiver.sync
                      i = -1
                      @synchronize.each_with_index do |e, j|
                        if e.processor == receiver
                          i = j
                          break
                        end
                      end
                      @synchronize[i] = SyncEntry.new(
                        @synchronize[i].processor,
                        Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
                      ) unless @synchronize[i].bag
                      @synchronize[i]
                    else
                      receiver.sync = true
                      e = SyncEntry.new(
                        receiver,
                        Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
                      )
                      @synchronize << e
                      e
                    end

            if child.is_a?(Coordinator)
              entry.bag.not_nil![dst].concat(payload.as(Array(Any)))
            else
              entry.bag.not_nil![dst] << payload.as(Any)
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
          @synchronize << SyncEntry.new(child.as(Processor))
        end
      end

      coupled.notify_observers(OBS_INFO_COLLECT_PHASE)

      @parent_bag
    end

    EMPTY_BAG = Hash(InputPort, Array(Any)).new

    def perform_transitions(time, bag)
      bag.each do |port, sub_bag|
        # check external input couplings to get children who receive sub-bag of y
        @model.as(CoupledModel).each_input_coupling(port) do |src, dst|
          receiver = dst.host.processor

          entry = if receiver.sync
                    i = -1
                    @synchronize.each_with_index do |e, j|
                      if e.processor == receiver
                        i = j
                        break
                      end
                    end

                    @synchronize[i] = SyncEntry.new(
                      @synchronize[i].processor,
                      Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
                    ) unless @synchronize[i].bag

                    @synchronize[i]
                  else
                    receiver.sync = true
                    e = SyncEntry.new(
                      receiver,
                      Hash(InputPort, Array(Any)).new { |h, k| h[k] = Array(Any).new }
                    )
                    @synchronize << e
                    e
                  end

          entry.bag.not_nil![dst].concat(sub_bag)
        end
      end

      @synchronize.each do |entry|
        receiver = entry.processor
        receiver.sync = false

        sub_bag = entry.bag || EMPTY_BAG # avoid useless allocations

        if @scheduler.is_a?(RescheduleEventSet)
          receiver.perform_transitions(time, sub_bag)
        elsif @scheduler.is_a?(LadderQueue)
          # Special case for the ladder queue

          tn = receiver.time_next
          # Before trying to cancel a receiver, test if time is not strictly
          # equal to its tn. If true, it means that its model will
          # receiver either an internal transition or a confluent transition,
          # and that the receiver is no longer in the scheduler.
          is_in_scheduler = tn < Quartz::INFINITY && time != tn
          if is_in_scheduler
            # The ladder queue might successfully delete the event if it is
            # stored in the *ladder* tier, but is allowed to return nil since
            # deletion strategy is based on event invalidation.
            if @scheduler.delete(receiver)
              is_in_scheduler = false
            end
          end
          new_tn = receiver.perform_transitions(time, sub_bag)

          # No need to reschedule the event if its tn is equal to INFINITY.
          # If a ta(s)=0 occured and that the old event is still present in
          # the ladder queue, we don't need to reschedule it either.
          if new_tn < Quartz::INFINITY && (!is_in_scheduler || (new_tn > tn && is_in_scheduler))
            @scheduler.push(receiver)
          end
        else
          tn = receiver.time_next
          # before trying to cancel a receiver, test if time is not strictly
          # equal to its time_next. If true, it means that its model will
          # receiver either an internal transition or a confluent transition,
          # and that the receiver is no longer in the scheduler.
          @scheduler.delete(receiver) if tn < Quartz::INFINITY && time != tn
          tn = receiver.perform_transitions(time, sub_bag)
          @scheduler.push(receiver) if tn < Quartz::INFINITY
        end
      end

      @scheduler.reschedule! if @scheduler.is_a?(RescheduleEventSet)

      @synchronize.clear

      @model.as(CoupledModel).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

      @time_last = time
      @time_next = min_time_next
    end
  end
end
