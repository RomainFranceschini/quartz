module Quartz
  module DSDE
    class Coordinator < Quartz::Coordinator

      def perform_transitions(time, bag)
        coupled = @model.as(Quartz::DSDE::CoupledModel)

        bag.each do |port, sub_bag|
          # check external input couplings to get children who receive sub-bag of y
          coupled.each_input_coupling(port) do |src, dst|
            receiver = dst.host.processor.not_nil!

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
                Hash(Port,Array(Any)).new { |h,k| h[k] = Array(Any).new }
              ) unless @synchronize[i].bag

              @synchronize[i]
            else
              receiver.sync = true
              e = SyncEntry.new(
                receiver,
                Hash(Port,Array(Any)).new { |h,k| h[k] = Array(Any).new }
              )
              @synchronize << e
              e
            end

            entry.bag.not_nil![dst].concat(sub_bag)
          end
        end

        old_children = coupled.each_child.to_a
        executive_bag : Hash(Port,Array(Any)) = EMPTY_BAG

        @synchronize.each do |entry|
          receiver = entry.processor
          if receiver.model == coupled.executive
            executive_bag = entry.bag.not_nil! if entry.bag
            next
          end

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
            # receiver either an internal_transition or a confluent transition,
            # and that the receiver is no longer in the scheduler
            @scheduler.delete(receiver) if tn < Quartz::INFINITY && time != tn
            tn = receiver.perform_transitions(time, sub_bag)
            @scheduler.push(receiver) if tn < Quartz::INFINITY
          end
        end

        receiver = coupled.executive.processor.not_nil!
        if receiver.sync
          receiver.sync = false

          if @scheduler.is_a?(RescheduleEventSet)
            receiver.perform_transitions(time, executive_bag)
          else
            tn = receiver.time_next
            @scheduler.delete(receiver) if tn < Quartz::INFINITY && time != tn
            tn = receiver.perform_transitions(time, executive_bag)
            @scheduler.push(receiver) if tn < Quartz::INFINITY
          end
        end

        current_children = coupled.each_child.to_a

        # unschedule processors of deleted models
        to_remove = old_children - current_children
        to_remove.each do |old_model|
          old_processor = old_model.processor.not_nil!
          if @scheduler.is_a?(RescheduleEventSet)
            @scheduler.delete(old_processor)
          else
            @scheduler.delete(old_processor) if old_processor.time_next < Quartz::INFINITY
          end
        end

        # initialize new models and their processors
        new_children = current_children - old_children
        new_children.each do |new_model|
          processor = ProcessorFactory.processor_for(new_model, @scheduler_type)
          self << processor

          tn = processor.initialize_processor(time)
          if @scheduler.is_a?(RescheduleEventSet)
            @scheduler << processor
          else
            @scheduler << processor if tn < Quartz::INFINITY
          end
        end

        @scheduler.reschedule! if @scheduler.is_a?(RescheduleEventSet)
        @synchronize.clear

        @time_last = time
        @time_next = min_time_next
      end
    end
  end
end
