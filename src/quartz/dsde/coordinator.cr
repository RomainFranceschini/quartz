module Quartz
  module DSDE
    class Coordinator < Quartz::Coordinator

      def perform_transitions(time, bag)
        coupled = @model.as(Quartz::DSDE::CoupledModel)

        bag.each do |port, sub_bag|
          # check external input couplings to get children who receive sub-bag of y
          coupled.each_input_coupling(port) do |src, dst|
            receiver = dst.host.processor.not_nil!
            @influencees[receiver][dst].concat(sub_bag)
            @synchronize << receiver
          end
        end

        old_children = coupled.each_child.to_a

        @synchronize.each do |receiver|
          next if receiver.model == coupled.executive
          sub_bag = @influencees[receiver]
          if @scheduler.is_a?(RescheduleEventSet)
            receiver.perform_transitions(time, sub_bag)
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
          sub_bag.clear
        end

        receiver = coupled.executive.processor.not_nil!
        if @synchronize.includes?(receiver)
          sub_bag = @influencees[receiver]
          if @scheduler.is_a?(RescheduleEventSet)
            receiver.perform_transitions(time, sub_bag)
          else
            tn = receiver.time_next
            @scheduler.delete(receiver) if tn < Quartz::INFINITY && time != tn
            tn = receiver.perform_transitions(time, sub_bag)
            @scheduler.push(receiver) if tn < Quartz::INFINITY
          end
          sub_bag.clear
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
        # NOTE: Set#clear is more time consuming (without --release flag) but
        # puts allocating a new set puts more stress on GC
        #@synchronize = Set(Processor).new
        @synchronize.clear

        @time_last = time
        @time_next = min_time_next
      end
    end
  end
end
