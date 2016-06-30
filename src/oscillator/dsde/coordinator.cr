module DEVS
  module PDEVS
    module DSDE
      class Coordinator < PDEVS::Coordinator

        def perform_transitions(time, bag)
          coupled = @model as CoupledModel

          bag.each do |port, sub_bag|
            # check external input couplings to get children who receive sub-bag of y
            coupled.each_input_coupling(port) do |src, dst|
              receiver = dst.host.processor.not_nil!
              @influencees[receiver][dst].concat(sub_bag)
              @synchronize << receiver
            end
          end

          old_children = coupled.children_names

          @synchronize.each do |receiver|
            #next if receiver.model == @model.executive

            sub_bag = @influencees[receiver]
            if @scheduler.is_a?(RescheduleEventSet)
              receiver.perform_transitions(time, sub_bag)
            else
              tn = receiver.time_next
              # before trying to cancel a receiver, test if time is not strictly
              # equal to its time_next. If true, it means that its model will
              # receiver either an internal_transition or a confluent transition,
              # and that the receiver is no longer in the scheduler
              @scheduler.delete(receiver) if tn < DEVS::INFINITY && time != tn
              tn = receiver.perform_transitions(time, sub_bag)
              @scheduler.push(receiver) if tn < DEVS::INFINITY
            end
            sub_bag.clear
          end

          # receiver = @model.executive.processor as Simulator
          # if @synchronize.includes?(receiver)
          #   sub_bag = @influencees[receiver]
          #   if @scheduler.is_a?(RescheduleEventSet)
          #     receiver.perform_transitions(time, sub_bag)
          #   else
          #     tn = receiver.time_next
          #     # before trying to cancel a receiver, test if time is not strictly
          #     # equal to its time_next. If true, it means that its model will
          #     # receiver either an internal_transition or a confluent transition,
          #     # and that the receiver is no longer in the scheduler
          #     @scheduler.delete(receiver) if tn < DEVS::INFINITY && time != tn
          #     tn = receiver.perform_transitions(time, sub_bag)
          #     @scheduler.push(receiver) if tn < DEVS::INFINITY
          #   end
          #   sub_bag.clear
          # end


          # initialize new models and their processors
          new_children = coupled.children_names - old_children
          new_children.each do |name|
            new_model = coupled[name]


            processor = if new_model.is_a?(CoupledModel)
              (new_model as CoupledModel).class.processor_for(@namespace).new(new_model, @namespace, @scheduler_type)
            else
              (new_model as AtomicModel).class.processor_for(@namespace).new(new_model)
            end
            self << processor

            tn = processor.initialize_processor(time)
            if @scheduler.is_a?(RescheduleEventSet)
              @scheduler << processor
            else
              @scheduler << processor if tn < DEVS::INFINITY
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
end
