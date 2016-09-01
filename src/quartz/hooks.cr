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
        @listeners.try &.[hook].delete(instance)
      end

      def clear
        @listeners.try &.clear
      end

      def clear(hook : Symbol)
        @listeners.try &.delete(hook)
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
