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
          if receiver.is_a?(Processor) && receiver.model == coupled.executive
            next
          end
          perform_transition_for(receiver.as(Processor | TimeBase), time)
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

            elapsed_duration = nil
            if old_processor.is_a?(DTSS::Simulator)
              delta_t = old_model.as(DTSS::AtomicModel).time_delta
              time_base = @time_bases[delta_t]
              time_base.processors.delete(old_processor) # TODO optimize 😱
              if time_base.processors.empty?
                @time_bases.delete(delta_t)
                @event_set.cancel_event(time_base.as(Schedulable))
                elapsed_duration = @time_cache.elapsed_duration_of(time_base.as(Schedulable))
                @time_cache.release_event(time_base.as(Schedulable))
              end
            else
              if !@event_set.duration_of(old_processor.as(Schedulable)).infinite?
                @event_set.cancel_event(old_processor.as(Schedulable))
              end
              elapsed_duration = @time_cache.elapsed_duration_of(old_processor.as(Schedulable))
              @time_cache.release_event(old_processor.as(Schedulable))
            end

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

            if processor.is_a?(DTSS::Simulator)
              delta_t = processor.model.as(DTSS::AtomicModel).time_delta
              time_base = @time_bases[delta_t] ||= TimeBase.new(delta_t)
              time_base.processors << processor
              processor.initialize_processor(time)
              if time_base.processors.size == 1
                @time_cache.retain_event(time_base, Duration.zero(time_base.time_next.precision))
                @event_set.plan_event(time_base, time_base.time_next)
              end
            else
              elapsed, planned_duration = processor.initialize_processor(time)
              @time_cache.retain_event(processor.as(Schedulable), elapsed)
              if !planned_duration.infinite?
                @event_set.plan_event(processor.as(Schedulable), planned_duration)
              else
                processor.as(Schedulable).planned_phase = planned_duration
              end
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
