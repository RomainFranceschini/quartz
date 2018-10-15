module Quartz
  module MultiComponent
    # This class defines a multiPDEVS simulator.
    class Simulator < Quartz::Simulator
      # :nodoc:
      OBS_INFO_REAC_TRANSITION = {:transition => Any.new(:reaction)}

      @components : Hash(Name, Component)
      @event_set : EventSet(Component)
      @time_cache : TimeCache(Component)
      @imm : Array(Quartz::MultiComponent::Component)
      @state_bags : Hash(Quartz::MultiComponent::Component, Array(Tuple(Name, Any)))
      @parent_bag : Hash(OutputPort, Array(Any))
      @reac_count : UInt32 = 0u32

      def initialize(model, simulation)
        super(model, simulation)
        sched_type = model.class.preferred_event_set? || simulation.default_scheduler
        @event_set = EventSet(Component).new(sched_type)
        @time_cache = TimeCache(Component).new(@event_set.current_time)
        @state_bags = Hash(Quartz::MultiComponent::Component, Array(Tuple(Name, Any))).new { |h, k|
          h[k] = Array(Tuple(Name, Any)).new
        }
        @imm = Array(Quartz::MultiComponent::Component).new
        @parent_bag = Hash(OutputPort, Array(Any)).new { |h, k|
          h[k] = Array(Any).new
        }
        @components = model.components
        @components.each_value { |component| component.processor = self }
      end

      def transition_stats
        {
          external:  @ext_count,
          internal:  @int_count,
          confluent: @con_count,
          reaction:  @reac_count,
        }
      end

      def initialize_processor(time : TimePoint) : {Duration, Duration}
        @reac_count = @int_count = @ext_count = @con_count = 0u32
        @event_set.clear
        @time_cache.current_time = @event_set.current_time
        @event_set.advance until: time

        max_elapsed = Duration.new(0)

        @components.each_value do |component|
          component.__initialize_state__(self)
          elapsed = component.elapsed
          planned_duration = component.time_advance

          if (logger = Quartz.logger?) && logger.debug?
            logger.debug(String.build { |str|
              str << '\'' << component.name << "' initialized ("
              str << "elapsed: " << elapsed << ", time_next: "
              str << planned_duration << ')'
            })
          end

          component.notify_observers(OBS_INFO_INIT_TRANSITION)

          @time_cache.retain_event(component, elapsed)
          if !planned_duration.infinite?
            @event_set.plan_event(component, planned_duration)
          else
            component.planned_phase = planned_duration
          end

          max_elapsed = elapsed if elapsed > max_elapsed
        end

        @model.as(MultiComponent::Model).notify_observers(OBS_INFO_INIT_PHASE)

        {max_elapsed.fixed, @event_set.imminent_duration.fixed}
      end

      def collect_outputs(elapsed : Duration)
        @event_set.advance by: elapsed

        @parent_bag.clear unless @parent_bag.empty?

        @event_set.each_imminent_event do |component|
          @imm << component
          if sub_bag = component.output
            sub_bag.each do |k, v|
              @parent_bag[k] << v
            end
          end
        end

        @model.as(MultiComponent::Model).notify_observers(OBS_INFO_COLLECT_PHASE)

        @parent_bag
      end

      def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
        bag = @bag || EMPTY_BAG

        if @event_set.current_time < time && !bag.empty?
          @event_set.advance until: time
        end

        if elapsed.zero? && bag.empty?
          @int_count += @imm.size
          @imm.each do |component|
            elapsed_duration = @time_cache.elapsed_duration_of(component)
            remaining_duration = @event_set.duration_of(component)
            component.elapsed = if remaining_duration.zero?
                                  Duration.zero(elapsed_duration.precision, elapsed_duration.fixed?)
                                else
                                  elapsed_duration
                                end

            # update elapsed values for each influencers
            component.influencers.each do |influencer|
              elapsed_influencer = @time_cache.elapsed_duration_of(component)
              influencer.elapsed = if elapsed_influencer == elapsed_duration
                                     Duration.zero(elapsed_influencer.precision, elapsed_influencer.fixed?)
                                   else
                                     elapsed_influencer
                                   end
            end

            component.internal_transition.try do |ps|
              ps.each do |k, v|
                @state_bags[@components[k]] << {component.name, v}
              end
            end
            if (logger = Quartz.logger?) && logger.debug?
              logger.debug(String.build { |str|
                str << '\'' << component.name << "': internal transition"
              })
            end
            component.notify_observers(OBS_INFO_INT_TRANSITION)
          end
        elsif !bag.empty?
          @components.each do |component_name, component|
            # TODO test if component defined delta_ext
            info = nil
            kind = nil
            elapsed_duration = @time_cache.elapsed_duration_of(component)
            remaining_duration = @event_set.duration_of(component)
            component.elapsed = if remaining_duration.zero?
                                  Duration.zero(elapsed_duration.precision, elapsed_duration.fixed?)
                                else
                                  elapsed_duration
                                end

            # update elapsed values for each influencers
            component.influencers.each do |influencer|
              elapsed_influencer = @time_cache.elapsed_duration_of(component)
              influencer.elapsed = if elapsed_influencer == elapsed_duration
                                     Duration.zero(elapsed_influencer.precision, elapsed_influencer.fixed?)
                                   else
                                     elapsed_influencer
                                   end
            end

            o = if elapsed.zero? && remaining_duration.zero?
                  info = OBS_INFO_CON_TRANSITION
                  kind = :confluent
                  @con_count += 1u32
                  component.confluent_transition(bag)
                else
                  info = OBS_INFO_EXT_TRANSITION
                  kind = :external
                  @ext_count += 1u32
                  component.external_transition(bag)
                end

            o.try &.each do |k, v|
              @state_bags[@components[k]] << {component_name, v}
            end

            if (logger = Quartz.logger?) && logger.debug?
              logger.debug(String.build { |str|
                str << '\'' << component.name << "': " << kind << " transition"
              })
            end

            component.notify_observers(info)
          end
        end

        bag.clear
        @imm.clear

        @state_bags.each do |component, states|
          remaining_duration = @event_set.duration_of(component)
          elapsed_duration = @time_cache.elapsed_duration_of(component)

          ev_deleted = if remaining_duration.zero?
                         elapsed_duration = Duration.zero(elapsed_duration.precision, elapsed_duration.fixed?)
                         true
                       elsif !remaining_duration.infinite?
                         @event_set.cancel_event(component) != nil
                       end

          component.elapsed = elapsed_duration
          component.reaction_transition(states)

          planned_duration = component.time_advance.fixed
          if planned_duration.infinite?
            component.planned_phase = Duration::INFINITY.fixed
          else
            if ev_deleted || (!ev_deleted && !planned_duration.zero?)
              @event_set.plan_event(component, planned_duration)
            end
          end
          @time_cache.retain_event(component, planned_duration.precision)

          if (logger = Quartz.logger?) && logger.debug?
            logger.debug(String.build { |str|
              str << '\'' << component.name << "': reaction transition ("
              str << "elapsed: " << elapsed_duration << ", time_next: " << planned_duration << ')'
            })
          end

          component.notify_observers(OBS_INFO_REAC_TRANSITION)
        end

        @reac_count += @state_bags.size
        @state_bags.clear

        @model.as(MultiComponent::Model).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

        @event_set.imminent_duration.fixed
      end
    end
  end
end
