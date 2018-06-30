module Quartz
  module DSDE
    class DynamicCoordinator < Quartz::Coordinator
      @simulation : Simulation

      def initialize(model, simulation)
        super(model, simulation)
        @simulation = simulation
      end

      def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
        coupled = @model.as(Quartz::DSDE::CoupledModel)
        bag = @bag || EMPTY_BAG

        if @event_set.current_time < time && !bag.empty?
          @event_set.advance until: time
        end

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
          elapsed_duration = @time_cache.elapsed_duration_of(receiver)

          remaining_duration = @event_set.duration_of(receiver)
          if remaining_duration.zero?
            elapsed_duration = Duration.zero(elapsed_duration.precision, elapsed_duration.fixed?)
          elsif !remaining_duration.infinite?
            @event_set.cancel_event(receiver)
          end

          planned_duration = receiver.perform_transitions(time, elapsed_duration)

          if planned_duration.infinite?
            receiver.planned_phase = Duration::INFINITY.fixed
          else
            @event_set.plan_event(receiver, planned_duration)
          end
          @time_cache.retain_event(receiver, planned_duration.precision)

          # end
        end

        receiver = coupled.executive.processor
        if receiver.sync
          receiver.sync = false
          elapsed_duration = @time_cache.elapsed_duration_of(receiver)

          remaining_duration = @event_set.duration_of(receiver)
          if remaining_duration.zero?
            elapsed_duration = Duration.zero(elapsed_duration.precision, elapsed_duration.fixed?)
          elsif !remaining_duration.infinite?
            @event_set.cancel_event(receiver)
          end

          planned_duration = receiver.perform_transitions(time, elapsed_duration)

          if planned_duration.infinite?
            receiver.planned_phase = Duration::INFINITY.fixed
          else
            @event_set.plan_event(receiver, planned_duration)
          end
          @time_cache.retain_event(receiver, planned_duration.precision)
        end

        current_children = coupled.each_child.to_a

        # unschedule processors of deleted models
        to_remove = old_children - current_children
        to_remove.each do |old_model|
          old_processor = old_model.processor

          if !@event_set.duration_of(old_processor).infinite?
            @event_set.cancel_event(old_processor)
          end
          @time_cache.release_event(old_processor)
        end

        # initialize new models and their processors
        new_children = current_children - old_children
        new_children.each do |new_model|
          visitor = ProcessorAllocator.new(@simulation, self)
          new_model.accept(visitor)
          processor = new_model.processor.not_nil!

          elapsed, planned_duration = processor.initialize_processor(time)
          @time_cache.retain_event(processor, elapsed)
          if !planned_duration.infinite?
            @event_set.plan_event(processor, planned_duration)
          else
            processor.planned_phase = planned_duration
          end
        end

        # @event_set.reschedule! if @event_set.is_a?(ReschedulePriorityQueue)
        bag.clear
        @synchronize.clear
        @model.as(CoupledModel).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

        @event_set.imminent_duration.fixed
      end
    end
  end
end
