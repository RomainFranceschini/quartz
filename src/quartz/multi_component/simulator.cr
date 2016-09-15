module Quartz
  module MultiComponent
    abstract class Simulator < Quartz::Simulator

      @components : Hash(Name, Component)

      @event_set : EventSet(Component)

      def initialize(model, scheduler : Symbol)
        super(model)
        @event_set = EventSetFactory(Component).new_event_set(scheduler)
        @components = model.components
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

    end
  end
end
