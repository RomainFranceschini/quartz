module Quartz
  module DSDE
    class DynamicCoordinator < Quartz::Coordinator
      @simulation : Simulation

      def initialize(model, simulation)
        super(model, simulation)
        @simulation = simulation
      end

      def perform_transitions(time)
        coupled = @model.as(Quartz::DSDE::CoupledModel)
        bag = @bag || EMPTY_BAG

        bag.each do |port, sub_bag|
          # check external input couplings to get children who receive sub-bag of y
          coupled.each_input_coupling(port) do |src, dst|
            receiver = dst.host.processor

            if !receiver.sync
              @synchronize << receiver
              receiver.sync = true
            end

            receiver.bag[dst].concat(sub_bag)
          end
        end

        old_children = coupled.each_child.to_a

        @synchronize.each do |receiver|
          if receiver.model == coupled.executive
            next
          end

          receiver.sync = false

          if @scheduler.is_a?(RescheduleEventSet)
            receiver.perform_transitions(time)
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
            new_tn = receiver.perform_transitions(time)

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
            # receiver either an internal_transition or a confluent transition,
            # and that the receiver is no longer in the scheduler
            @scheduler.delete(receiver) if tn < Quartz::INFINITY && time != tn
            tn = receiver.perform_transitions(time)
            @scheduler.push(receiver) if tn < Quartz::INFINITY
          end
        end

        receiver = coupled.executive.processor
        if receiver.sync
          receiver.sync = false

          if @scheduler.is_a?(RescheduleEventSet)
            receiver.perform_transitions(time)
          elsif @scheduler.is_a?(LadderQueue)
            tn = receiver.time_next
            is_in_scheduler = tn < Quartz::INFINITY && time != tn
            if is_in_scheduler
              if @scheduler.delete(receiver)
                is_in_scheduler = false
              end
            end
            new_tn = receiver.perform_transitions(time)
            if new_tn < Quartz::INFINITY && (!is_in_scheduler || (new_tn > tn && is_in_scheduler))
              @scheduler.push(receiver)
            end
          else
            tn = receiver.time_next
            @scheduler.delete(receiver) if tn < Quartz::INFINITY && time != tn
            tn = receiver.perform_transitions(time)
            @scheduler.push(receiver) if tn < Quartz::INFINITY
          end
        end

        current_children = coupled.each_child.to_a

        # unschedule processors of deleted models
        to_remove = old_children - current_children
        to_remove.each do |old_model|
          old_processor = old_model.processor
          if @scheduler.is_a?(RescheduleEventSet)
            @scheduler.delete(old_processor)
          else
            @scheduler.delete(old_processor) if old_processor.time_next < Quartz::INFINITY
          end
        end

        # initialize new models and their processors
        new_children = current_children - old_children
        new_children.each do |new_model|
          visitor = ProcessorAllocator.new(@simulation, self)
          new_model.accept(visitor)
          processor = new_model.processor.not_nil!

          tn = processor.initialize_processor(time)
          if @scheduler.is_a?(RescheduleEventSet)
            @scheduler << processor
          else
            @scheduler << processor if tn < Quartz::INFINITY
          end
        end

        @scheduler.reschedule! if @scheduler.is_a?(RescheduleEventSet)
        bag.clear
        @synchronize.clear
        @model.as(CoupledModel).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

        @time_last = time
        @time_next = min_time_next
      end
    end
  end
end
