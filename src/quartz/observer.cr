module Quartz
  # The `Observer` module is intended to be included in a class as a mixin.
  # It provides a protocol so that objects can register to `Observable` objects
  # and receives their updates, along with additional optional information.
  #
  # Observers must define an `#update` method.
  module Observer
    # This method is called whenever the observed object (*observable*) is
    # changed. A dictionary representing additional information, *info*,
    # may be available, or `nil` otherwise.
    abstract def update(observable : Observable, info)
  end

  # The Observer pattern (publish/subscribe) provides a simple mechanism for
  # one object to inform a set of interested third-party objects when its state
  # changes.
  #
  # The notifying class mixes in the `Observable` module, which provides the
  # methods for managing the associated observer objects.
  # The observable object must call `#notify_observers` to notify its observers.
  #
  # An observer object must conforms to the `Observer` protocol. It subscribes
  # to updates using `#add_observer`.
  #
  # Example 1: Observing model state changes
  #
  # ```
  # class MyObserver
  #   include Quartz::Observer
  #
  #   def update(observable, info)
  #     if observable.is_a?(MyModel)
  #       model = observable.as(MyModel)
  #       puts "#{model.name} changed its state to #{model.phase}"
  #     end
  #   end
  # end
  #
  # model = MyModel.new("mymodel")
  # model.add_observer(MyObserver.new)
  # Quartz::Simulation.new(model).simulate
  # ```
  #
  # Example 2: Observing outputs on a port.
  #
  # ```
  # class MyObserver
  #   include Quartz::Observer
  #
  #   def update(observable, info)
  #     if observable.is_a?(Port) && info
  #       puts "port '#{port.name}' sends value '#{info[:payload]}'"
  #     end
  #   end
  # end
  #
  # model = MyModel.new("mymodel")
  # model.output_port(:out).add_observer(MyObserver.new)
  # Quartz::Simulation.new(model).simulate
  # ```
  module Observable
    @observers : Array(Observer)?

    # Adds *observer* to the list of observers so that it will receive future
    # updates.
    def add_observer(observer : Observer)
      @observers ||= [] of (Observer)
      @observers.not_nil! << observer
    end

    # Removes *observer* from the list of observers so that it will no longer
    # receive updates.
    def delete_observer(observer : Observer) : Bool
      @observers.try(&.delete(observer)) != nil
    end

    # Returns the number of objects currently observing this object.
    def count_observers
      if obs = @observers
        obs.size
      else
        0
      end
    end

    # Notifies observers of a change in state. A dictionary, *info*, can be
    # passed to observers that conforms to the `Observer` protocol.
    def notify_observers(info = nil)
      @observers.try &.each do |observer|
        observer.update(self, info)
      end
    end
  end
end
