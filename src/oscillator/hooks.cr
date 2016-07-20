module DEVS
  module Hooks

    # TODO add a dedicated `Notifier` in `Simulation`
    def self.notifier
      @@notifier ||= Notifier.new
    end

    module Notifiable
      abstract def notify(hook : Symbol);
    end

    class Notifier
      @listeners : Hash(Symbol, Array(Proc(Symbol,Void) | Notifiable))?

      def subscribe(hook : Symbol, notifiable : Notifiable)
        @listeners ||= Hash(Symbol, Array(Proc(Symbol,Void) | Notifiable)).new { |h,k| h[k] = [] of (Proc(Symbol,Void) | Notifiable) }
        @listeners.not_nil![hook] << notifiable
      end

      def subscribe(hook : Symbol, &block : Symbol -> Void)
        @listeners ||= Hash(Symbol, Array(Proc(Symbol,Void) | Notifiable)).new { |h,k| h[k] = [] of (Proc(Symbol,Void) | Notifiable) }
        @listeners.not_nil![hook] << block
      end

      def unsubscribe(hook : Symbol, instance : Proc(Symbol,Void) | Notifiable)
        @listeners.try &.[hook].delete(instance)
      end

      def clear
        @listeners.try &.clear
      end

      def notify(hook : Symbol)
        @listeners.try do |listeners|
          listeners[hook].each do |n|
            begin
              n.is_a?(Notifiable) ? n.notify(hook) : n.call(hook)
            rescue
              #unsubscribe(hook, n)
            end
          end
        end
      end
    end
  end
end
