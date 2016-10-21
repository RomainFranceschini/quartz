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
      @listeners : Hash(Symbol, Array(Proc(Symbol,Nil) | Notifiable))?

      def subscribe(hook : Symbol, notifiable : Notifiable)
        @listeners ||= Hash(Symbol, Array(Proc(Symbol,Nil) | Notifiable)).new { |h,k| h[k] = [] of (Proc(Symbol,Nil) | Notifiable) }
        @listeners.not_nil![hook] << notifiable
      end

      def subscribe(hook : Symbol, &block : Symbol ->)
        @listeners ||= Hash(Symbol, Array(Proc(Symbol,Nil) | Notifiable)).new { |h,k| h[k] = [] of (Proc(Symbol,Nil) | Notifiable) }
        @listeners.not_nil![hook] << block
      end

      def unsubscribe(hook : Symbol, instance : Proc(Symbol,Nil) | Notifiable)
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
