module Quartz
  module MultiComponent
    class Simulator < Quartz::Simulator

      @components : Hash(Name, Component)
      @event_set : EventSet(Component)
      @imm : Array(Quartz::MultiComponent::Component)?

      @state_bags = Hash(Quartz::MultiComponent::Component,Array(Tuple(Name,Any))).new { |h,k| h[k] = Array(Tuple(Name,Any)).new }

      def initialize(model, scheduler : Symbol)
        super(model)
        @event_set = EventSetFactory(Component).new_event_set(scheduler)
        @components = model.components
        @transition_count = Hash(Symbol, UInt64).new { 0_u64 }
      end

      def transition_stats
        @transition_count
      end

      def initialize_processor(time)
        atomic = @model.as(MultiComponent::Model)
        @transition_count.clear

        @event_set.clear

        @components.each_value do |component|
          #component.notify_observers(component, :init)
          component.time_last = component.time = time - component.elapsed
          component.time_next = component.time_last + component.time_advance

          case @event_set
          when RescheduleEventSet
            @event_set << component
          else
            if component.time_next < Quartz::INFINITY
              @event_set << component
            end
          end
        end

        @time_last = time
        @time_next = min_time_next
      end

      # Returns the minimum time next in all components
      def min_time_next
        tn = Quartz::INFINITY
        if (obj = @event_set.peek)
          tn = obj.time_next
        end
        tn
      end

      def collect_outputs(time) : Hash(Port, Array(Any))
        raise BadSynchronisationError.new("time: #{time} should match time_next: #{@time_next}") if time != @time_next

        @imm = if @event_set.is_a?(RescheduleEventSet)
          @event_set.peek_all(time)
        else
          @event_set.delete_all(time)
        end

        output_bag = Hash(Port,Array(Any)).new { |h,k| h[k] = Array(Any).new }

        @imm.not_nil!.each do |component|
          if sub_bag = component.output
            sub_bag.each do |k,v|
              output_bag[@model.ensure_output_port(key)] << v
            end
          end
        end

        output_bag
      end

      def perform_transitions(time, bag)
        if !(@time_last <= time && time <= @time_next)
          raise BadSynchronisationError.new("time: #{time} should be between time_last: #{@time_last} and time_next: #{@time_next}")
        end

        kind = :unknown
        if time == @time_next && bag.empty?
          kind = :internal
          @imm.not_nil!.each do |component|
            component.internal_transition.try do |ps|
              ps.each do |k,v|
                @state_bags[@components[k]] << {component.name, v}
              end
            end
            #component.notify_observers(component, kind)
          end
        elsif !bag.empty?
          @components.each do |component_name, component|
            # TODO test if component defined delta_ext
            o = if time == @time_next && component.time_next == @time_next
              kind = :confluent
              component.confluent_transition(bag)
            else
              kind = :external
              component.external_transition(bag)
            end
            #component.notify_observers(component, kind)
            o.try &.each do |k,v|
              @state_bags[@components[k]] << {component_name, v}
            end
          end
        end

        @state_bags.each do |component, states|
          if @event_set.is_a?(RescheduleEventSet)
            component.reaction_transition(states)
            component.time_last = component.time = time - component.elapsed
            component.time_next = component.time_last + component.time_advance
          else
            tn = component.time_next
            @event_set.delete(component) if tn < Quartz::INFINITY && time != tn
            component.reaction_transition(states)
            component.time_last = component.time = time - component.elapsed
            tn = component.time_next = component.time_last + component.time_advance
            @event_set.push(component) if tn < Quartz::INFINITY
          end
          #component.notify_observers(component, :reaction)
        end
        @state_bags.clear

        @event_set.reschedule! if @event_set.is_a?(RescheduleEventSet)

        #@model.as(MultiComponent::Model).notify_observers(@model.as(MultiComponent::Model), kind)

        @time_last = time
        @time_next = min_time_next
      end

    end
  end
end
