module DEVS
  module Observable(T)
    @observers : Array(T)?

    def add_observer(observer : T)
      @observers ||= [] of T
      @observers.not_nil! << observer
    end

    def delete_observer(observer : T) : Bool
      @observers.try(&.delete(observer))
    end

    def count_observers
      @observers.try(&.size)
    end

    def notify_observers(*args)
      @observers.try(&.each(&.update(*args)))
    end
  end

  module PortObserver
    abstract def update(port : Port, payload : Any);
  end

  module TransitionObserver
    abstract def update(model : Behavior, transition : Symbol);
  end

end
