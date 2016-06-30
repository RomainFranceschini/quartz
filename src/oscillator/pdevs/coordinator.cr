module DEVS
  module PDEVS
    class Coordinator < DEVS::Coordinator

      def initialize(model, namespace, scheduler)
        super(model, namespace, scheduler)
        # @influencees = Hash(Processor, Hash(Port,Array(Type))).new { |h,k| h[k] = Hash(Port,Array(Type)).new { |h2,k2| h2[k2] = Array(Type).new }}
        # @synchronize = Set(Processor).new
        # @parent_bag = Hash(Port,Array(Type)).new { |h,k| h[k] = Array(Type).new }
        @influencees = Hash(Processor, Hash(Port,Array(Any))).new { |h,k| h[k] = Hash(Port,Array(Any)).new { |h2,k2| h2[k2] = Array(Any).new }}
        @synchronize = Set(Processor).new
        @parent_bag = Hash(Port,Array(Any)).new { |h,k| h[k] = Array(Any).new }
      end

      def initialize_processor(time)
        min = DEVS::INFINITY
        selected = Array(Processor).new
        @children.each do |child|
          tn = child.initialize_processor(time)
          selected.push(child) if tn < DEVS::INFINITY
          min = tn if tn < min
        end

        @scheduler.clear
        list = @scheduler.is_a?(RescheduleEventSet) ? @children : selected
        list.each { |c| @scheduler << c }

        @time_last = max_time_last
        @time_next = min
      end

      def collect_outputs(time) : Hash(Port, Array(Any))
        if time != @time_next
          raise BadSynchronisationError.new("\ttime: #{time} should match time_next: #{@time_next}")
        end
        @time_last = time

        imm = if @scheduler.is_a?(RescheduleEventSet)
          @scheduler.peek_all(time)
        else
          @scheduler.delete_all(time)
        end

        coupled = @model as CoupledModel
        @parent_bag.clear unless @parent_bag.empty?

        imm.each do |child|
          @synchronize << child
          output = child.collect_outputs(time)

          output.each do |port, payload|
            port.notify_observers(port, payload)

            # check internal coupling to get children who receive sub-bag of y
            coupled.each_internal_coupling(port) do |src, dst|
              receiver = dst.host.processor.not_nil!
              if child.is_a?(Coordinator)
                @influencees[receiver][dst].concat(payload as Array(Any))
              else
                @influencees[receiver][dst] << payload as Any
              end
              @synchronize << receiver
            end

            # check external coupling to form sub-bag of parent output
            coupled.each_output_coupling(port) do |src, dst|
              if child.is_a?(Coordinator)
                @parent_bag[dst].concat(payload as Array(Any))
              else
                @parent_bag[dst] << (payload as Any)
              end
            end
          end
        end

        @parent_bag
      end

      def perform_transitions(time, bag)
        bag.each do |port, sub_bag|
          # check external input couplings to get children who receive sub-bag of y
          (@model as CoupledModel).each_input_coupling(port) do |src, dst|
            receiver = dst.host.processor.not_nil!
            @influencees[receiver][dst].concat(sub_bag)
            @synchronize << receiver
          end
        end

        @synchronize.each do |receiver|
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
        @scheduler.reschedule! if @scheduler.is_a?(RescheduleEventSet)

        # NOTE: Set#clear is more time consuming (without --release flag)
        #@synchronize = Set(Processor).new
        @synchronize.clear

        @time_last = time
        @time_next = min_time_next
      end
    end
  end
end
