module Quartz
  module MultiComponent
    # This class defines a multiPDEVS simulator.
    class Simulator < Quartz::Simulator

      # :nodoc:
      OBS_INFO_REAC_TRANSITION = { :transition => Any.new(:reaction) }

      @components : Hash(Name, Component)
      @event_set : EventSet(Component)
      @imm : Array(Quartz::MultiComponent::Component)
      @state_bags : Hash(Quartz::MultiComponent::Component,Array(Tuple(Name,Any)))
      @parent_bag : Hash(OutputPort, Array(Any))
      @reac_count : UInt32 = 0u32

      def initialize(model, simulation)
        super(model, simulation)
        sched_type = model.class.preferred_event_set? || simulation.default_scheduler
        @event_set = EventSet(Component).new(sched_type)
        @state_bags = Hash(Quartz::MultiComponent::Component,Array(Tuple(Name,Any))).new { |h,k|
          h[k] = Array(Tuple(Name,Any)).new
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
          external: @ext_count,
          internal: @int_count,
          confluent: @con_count,
          reaction: @reac_count
        }
      end

      # Returns the maximum time last in all components
      protected def max_time_last
        @components.each_value.reduce(-INFINITY) { |memo, child| Math.max(memo, child.time_last) }
      end

      def initialize_processor(time)
        @reac_count = @int_count = @ext_count = @con_count = 0u32
        @event_set.clear

        @components.each_value do |component|
          component.time_last = component.time = time - component.elapsed
          component.__initialize_state__(self)
          component.time_next = component.time_last + component.time_advance
          component.notify_observers(OBS_INFO_INIT_TRANSITION)

          case @event_set
          when RescheduleEventSet
            @event_set << component
          else
            if component.time_next < Quartz::INFINITY
              @event_set << component
            end
          end

          if (logger = Quartz.logger?) && logger.debug?
            logger.debug(String.build { |str|
              str << '\'' << component.name << "' initialized ("
              str << "tl: " << component.time_last << ", tn: "
              str << component.time_next << ')'
            })
          end
        end

        @time_last = max_time_last
        @time_next = min_time_next

        @model.as(MultiComponent::Model).notify_observers(OBS_INFO_INIT_PHASE)

        @time_next
      end

      # Returns the minimum time next in all components
      def min_time_next
        @event_set.next_priority
      end

      def collect_outputs(time)
        raise BadSynchronisationError.new("time: #{time} should match time_next: #{@time_next}") if time != @time_next

        @parent_bag.clear unless @parent_bag.empty?

        @event_set.each_imminent(time) do |component|
          @imm << component
          component.time = time
          if sub_bag = component.output
            sub_bag.each do |k,v|
              @parent_bag[@model.ensure_output_port(k)] << v
            end
          end
        end

        @model.as(MultiComponent::Model).notify_observers(OBS_INFO_COLLECT_PHASE)

        @parent_bag
      end

      def perform_transitions(time, bag)
        if !(@time_last <= time && time <= @time_next)
          raise BadSynchronisationError.new("time: #{time} should be between time_last: #{@time_last} and time_next: #{@time_next}")
        end

        if time == @time_next && bag.empty?
          @int_count += @imm.size
          @imm.each do |component|
            component.time = time
            component.elapsed = time - component.time_last
            component.influencers.each { |i| i.elapsed = time - i.time_last }
            component.internal_transition.try do |ps|
              ps.each do |k,v|
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
            component.time = time
            component.elapsed = time - component.time_last
            component.influencers.each { |i| i.elapsed = time - i.time_last }
            o = if time == @time_next && component.time_next == @time_next
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

            o.try &.each do |k,v|
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

        @imm.clear

        @state_bags.each do |component, states|
          component.time = time
          if @event_set.is_a?(RescheduleEventSet)
            component.reaction_transition(states)
            component.elapsed = 0
            component.time_last = time
            component.time_next = component.time_last + component.time_advance
          elsif @event_set.is_a?(LadderQueue)
            tn = component.time_next
            is_in_scheduler = tn < Quartz::INFINITY && time != tn
            if is_in_scheduler
              if @event_set.delete(component)
                is_in_scheduler = false
              end
            end
            component.reaction_transition(states)
            component.elapsed = 0
            component.time_last = time
            new_tn = component.time_next = component.time_last + component.time_advance
            if new_tn < Quartz::INFINITY && (!is_in_scheduler || (new_tn > tn && is_in_scheduler))
              @event_set.push(component)
            end
          else
            tn = component.time_next
            @event_set.delete(component) if tn < Quartz::INFINITY && time != tn
            component.reaction_transition(states)
            component.elapsed = 0
            component.time_last = time
            tn = component.time_next = component.time_last + component.time_advance
            @event_set.push(component) if tn < Quartz::INFINITY
          end

          if (logger = Quartz.logger?) && logger.debug?
            logger.debug(String.build { |str|
              str << '\'' << component.name << "': reaction transition "
              str << "(tl: " << component.time_last << ", tn: "
              str << component.time_next << ')'
            })
          end

          component.notify_observers(OBS_INFO_REAC_TRANSITION)
        end

        @reac_count += @state_bags.size
        @state_bags.clear

        @event_set.reschedule! if @event_set.is_a?(RescheduleEventSet)

        @model.as(MultiComponent::Model).notify_observers(OBS_INFO_TRANSITIONS_PHASE)

        @time_last = time
        @time_next = min_time_next
      end

    end
  end
end
