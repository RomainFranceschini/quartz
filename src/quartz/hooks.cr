module Quartz
  module Hooks

    # TODO add a dedicated `Notifier` in `Simulation`
    def self.notifier
      @@notifier ||= Notifier.new
    end

    module Notifiable
      abstract def notify(hook : Symbol);
    end

    class Notifier
      @listeners : Hash(Symbol, Array((Symbol ->) | Notifiable))?

      @[AlwaysInline]
      private def listeners
        @listeners ||= Hash(Symbol, Array((Symbol ->) | Notifiable)).new { |h,k| h[k] = Array(((Symbol ->) | Notifiable)).new }
      end

      def subscribe(hook : Symbol, notifiable : Notifiable)
        listeners[hook] << notifiable
      end

      def subscribe(hook : Symbol, &block : Symbol ->)
        listeners[hook] << block
      end

      def count_listeners(hook : Symbol)
        @listeners.try &.[hook].size
      end

      def count_listeners
        @listeners.try &.reduce(0) { |acc, tuple| acc + tuple[1].size }
      end

      def unsubscribe(hook : Symbol, instance : (Symbol ->) | Notifiable)
        @listeners.try(&.[hook].delete(instance)) != nil
      end

      def clear
        @listeners.try &.clear
      end

      def clear(hook : Symbol)
        @listeners.try &.delete(hook)
      end

      def notify(hook : Symbol)
        @listeners.try do |listeners|
          listeners[hook].reject! do |l|
            begin
              l.is_a?(Notifiable) ? l.notify(hook) : l.call(hook)
              false
            rescue
              true # deletes the element in place since it raised
            end
          end
        end
      end
    end
  end
end
