module Quartz
  module Hooks
    PRE_SIMULATION  = :pre_simulation
    POST_SIMULATION = :post_simulation
    PRE_INIT        = :pre_init
    POST_INIT       = :post_init
    PRE_ABORT       = :pre_abort
    POST_ABORT      = :post_abort
    PRE_RESTART     = :pre_restart
    POST_RESTART    = :post_restart

    # Returns the simulation default notifier.
    def self.notifier
      @@notifier ||= Notifier.new
    end

    # The `Notifiable` module is intended to be included in a class as a mixin.
    # It provides an interface so that objects can register and receive hooks
    # during a simulation via the `#notify` method that are dispatched by
    # a `Notifier`.
    module Notifiable
      # This method is called whenever a registered *hook* is dispatched.
      abstract def notify(hook : Symbol)
    end

    # The `Notifier` provides a mechanism for broadcasting hooks during a
    # simulation.
    #
    # Hooks can be dispatched either to `Proc`s or to `Notifiable` objects.
    # They can register to a hook using the `#subscribe` method. Each invocation
    # of this method registers the receiver to a given hook. Therefore,
    # objects may register to several hooks.
    #
    # A default `Notifier` instance is provided (`Hooks#notifier`) so that
    # objects can register to hooks sent during a simulation.
    class Notifier
      @listeners : Hash(Symbol, Array((Symbol ->) | Notifiable))?

      # :nodoc:
      private def listeners
        @listeners ||= Hash(Symbol, Array((Symbol ->) | Notifiable)).new { |h, k| h[k] = Array(((Symbol ->) | Notifiable)).new }
      end

      # Register the given *notifiable* to the specified *hook*.
      def subscribe(hook : Symbol, notifiable : Notifiable)
        listeners[hook] << notifiable
      end

      # Register the given *block* to the specified *hook*.
      def subscribe(hook : Symbol, &block : Symbol ->)
        listeners[hook] << block
      end

      # Returns the number of objects listening for the specified *hook*.
      def count_listeners(hook : Symbol)
        @listeners.try &.[hook].size
      end

      # Returns the total number of objects listening to hooks.
      def count_listeners
        @listeners.try &.reduce(0) { |acc, tuple| acc + tuple[1].size }
      end

      # Unsubscribes the specified entry from listening to the specified *hook*.
      def unsubscribe(hook : Symbol, instance : (Symbol ->) | Notifiable)
        @listeners.try(&.[hook].delete(instance)) != nil
      end

      # Removes all entries from the notifier.
      def clear
        @listeners.try &.clear
      end

      # Removes all entries that previously registered to the specified *hook*
      # from the notifier.
      def clear(hook : Symbol)
        @listeners.try &.delete(hook)
      end

      # Publish a given *hook*, so that each registered object in the receiver
      # is notified.
      def notify(hook : Symbol)
        @listeners.try do |listeners|
          listeners[hook].each do |l|
            l.is_a?(Notifiable) ? l.notify(hook) : l.call(hook)
          end
        end
      end
    end
  end
end
