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
        handle_external_inputs(time)

        old_children = coupled.each_child.to_a

        @synchronize.each do |receiver|
          if receiver.model == coupled.executive
            next
          end
          perform_transition_for(receiver, time)
        end

        receiver = coupled.executive.processor
        if receiver.sync
          perform_transition_for(receiver, time)
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

        bag.clear
        @synchronize.clear
        @model.as(CoupledModel).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

        @event_set.imminent_duration.fixed
      end
    end
  end
end
