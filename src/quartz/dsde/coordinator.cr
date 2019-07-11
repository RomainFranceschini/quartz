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
        executive = coupled.executive.processor

        @synchronize.each do |receiver|
          if receiver.model == coupled.executive
            next
          end
          perform_transition_for(receiver, time)
        end

        if executive.sync
          current_children = coupled.each_child.to_set

          perform_transition_for(executive, time)

          new_children = coupled.each_child.to_set

          # unschedule processors of deleted models
          # to_remove: contains elements in current_children that are not present in the new_children set.
          to_remove = current_children - new_children
          to_remove.each do |old_model|
            old_processor = old_model.processor

            if !@event_set.duration_of(old_processor).infinite?
              @event_set.cancel_event(old_processor)
            end
            elapsed_duration = @time_cache.elapsed_duration_of(old_processor)
            @time_cache.release_event(old_processor)

            if @simulation.loggers.any_debug?
              @simulation.loggers.debug(String.build { |str|
                str << '\'' << old_model.name << "' terminated ("
                str << "elapsed: " << elapsed_duration << ')'
              })
            end
          end

          # initialize new models and their processors
          # to_initialize: contains elements in new_children that are not present in the current_children set.
          to_initialize = new_children - current_children
          to_initialize.each do |new_model|
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
        end

        bag.clear
        @synchronize.clear

        if coupled.count_observers > 0
          coupled.notify_observers(OBS_INFO_TRANSITIONS_PHASE.merge({
            :time    => time,
            :elapsed => elapsed,
          }))
        end

        @event_set.imminent_duration.fixed
      end
    end
  end
end
