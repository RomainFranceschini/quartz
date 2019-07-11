module Quartz
  module MultiComponent
    # This class defines a multiPDEVS simulator.
    class Simulator < Quartz::Processor
      # :nodoc:
      OBS_INFO_REAC_TRANSITION = {:transition => Any.new(:reaction)}

      @components : Hash(Name, Component)
      @event_set : EventSet(Component)
      @time_cache : TimeCache(Component)
      @imm : Array(Quartz::MultiComponent::Component)
      @state_bags : Hash(Quartz::MultiComponent::Component, Array(Tuple(Name, Any)))
      @parent_bag : Hash(OutputPort, Array(Any))
      @reac_count : UInt32 = 0u32
      @int_count : UInt32 = 0u32
      @ext_count : UInt32 = 0u32
      @con_count : UInt32 = 0u32
      @run_validations : Bool
      @loggers : Loggers

      def initialize(model, simulation)
        super(model)
        sched_type = model.class.preferred_event_set? || simulation.default_scheduler
        @run_validations = simulation.run_validations?
        @loggers = simulation.loggers
        @event_set = EventSet(Component).new(sched_type, simulation.virtual_time)
        @time_cache = TimeCache(Component).new(simulation.virtual_time)
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
        @time_cache.current_time = @event_set.current_time = time

        max_elapsed = Duration.new(0)

        @components.each_value do |component|
          component.__initialize_state__(self)
          elapsed = component.elapsed
          planned_duration = component.time_advance.as(Duration)
          fixed_planned_duration = planned_duration.fixed_at(component.class.precision_level)
          if !planned_duration.infinite? && fixed_planned_duration.infinite?
            raise InvalidDurationError.new("#{model.name} planned duration cannot exceed #{Duration.new(Duration::MULTIPLIER_MAX, component.class.precision_level)} given its precision level.")
          elsif planned_duration.precision < component.class.precision_level
            raise InvalidDurationError.new("'#{component.name}': planned duration #{planned_duration} is rounded to #{fixed_planned_duration} due to the model precision level.")
          end

          if @loggers.any_debug?
            @loggers.debug(String.build { |str|
              str << '\'' << component.name << "' initialized ("
              str << "elapsed: " << elapsed << ", time_next: "
              str << planned_duration << ')'
            })
          end

          if component.count_observers > 0
            component.notify_observers(OBS_INFO_INIT_TRANSITION.merge({
              :time    => time,
              :elapsed => elapsed,
            }))
          end

          @time_cache.retain_event(component, elapsed)
          if !planned_duration.infinite?
            @event_set.plan_event(component, planned_duration)
          else
            component.planned_phase = planned_duration
          end

          max_elapsed = elapsed if elapsed > max_elapsed
        end

        multipdevs = @model.as(MultiComponent::Model)
        if multipdevs.count_observers > 0
          multipdevs.notify_observers(OBS_INFO_INIT_PHASE.merge({:time => time}))
        end

        {max_elapsed.fixed, @event_set.imminent_duration.fixed}
      end

      def collect_outputs(elapsed : Duration)
        @parent_bag.clear unless @parent_bag.empty?

        @event_set.each_imminent_event do |component|
          @imm << component
          if component.responds_to?(:output)
            if sub_bag = component.output
              sub_bag.each do |k, v|
                @parent_bag[k] << v
              end
            end
          end
        end

        multipdevs = @model.as(MultiComponent::Model)
        if multipdevs.count_observers > 0
          multipdevs.notify_observers(OBS_INFO_COLLECT_PHASE.merge({
            :time    => @event_set.current_time,
            :elapsed => elapsed,
          }))
        end

        @parent_bag
      end

      def perform_transitions(time : TimePoint, elapsed : Duration) : Duration
        bag = @bag || EMPTY_BAG

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
            if @loggers.any_debug?
              @loggers.debug(String.build { |str|
                str << '\'' << component.name << "': internal transition"
              })
            end
            if component.count_observers > 0
              component.notify_observers(OBS_INFO_INT_TRANSITION.merge({
                :time    => time,
                :elapsed => component.elapsed,
              }))
            end
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
                  if component.responds_to?(:external_transition)
                    info = OBS_INFO_CON_TRANSITION
                    kind = :confluent
                    @con_count += 1u32
                    component.confluent_transition(bag)
                  else
                    info = OBS_INFO_INT_TRANSITION
                    kind = :internal
                    @int_count += 1u32
                    component.internal_transition
                  end
                else
                  if component.responds_to?(:external_transition)
                    info = OBS_INFO_EXT_TRANSITION
                    kind = :external
                    @ext_count += 1u32
                    component.external_transition(bag)
                  end
                end

            if info
              o.try &.each do |k, v|
                @state_bags[@components[k]] << {component_name, v}
              end

              if @loggers.any_debug?
                @loggers.debug(String.build { |str|
                  str << '\'' << component.name << "': " << kind << " transition"
                })
              end

              if component.count_observers > 0
                component.notify_observers(info.merge({
                  :time    => time,
                  :elapsed => component.elapsed,
                }))
              end
            end
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
                       else
                         true
                       end

          component.elapsed = elapsed_duration
          component.reaction_transition(states)

          planned_duration = component.time_advance.as(Duration).fixed
          if planned_duration.infinite?
            component.planned_phase = Duration::INFINITY.fixed
          else
            if ev_deleted || (!ev_deleted && !planned_duration.zero?)
              @event_set.plan_event(component, planned_duration)
            end
          end
          @time_cache.retain_event(component, planned_duration.precision)

          if @loggers.any_debug?
            @loggers.debug(String.build { |str|
              str << '\'' << component.name << "': reaction transition ("
              str << "elapsed: " << elapsed_duration << ", time_next: " << planned_duration << ')'
            })
          end

          if component.count_observers > 0
            component.notify_observers(OBS_INFO_REAC_TRANSITION.merge({
              :time    => time,
              :elapsed => elapsed_duration,
            }))
          end
        end

        @reac_count += @state_bags.size
        @state_bags.clear

        multipdevs = @model.as(MultiComponent::Model)
        if multipdevs.count_observers > 0
          multipdevs.notify_observers(OBS_INFO_TRANSITIONS_PHASE.merge({
            :time    => time,
            :elapsed => elapsed,
          }))
        end

        @event_set.imminent_duration.fixed
      end
    end
  end
end
