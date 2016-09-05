module Quartz
  module Observable(T)
    @observers : Array(T)?

    def add_observer(observer : T)
      @observers ||= [] of T
      @observers.not_nil! << observer
    end

    def delete_observer(observer : T) : Bool
      @observers.try(&.delete(observer)) != nil
    end

    def count_observers
      @observers.try(&.size)
    end

    def notify_observers(*args)
      @observers.try do |observers|
        observers.each do |observer|
          begin
            observer.update(*args)
          rescue
            #delete_observer(observer)
          end
        end
      end
    end
  end

  module PortObserver
    abstract def update(port : Port, payload : Any);
  end

  module TransitionObserver
    #abstract def update(model : Model, transition : Symbol);
    abstract def update(model : Transitions, transition : Symbol);
  end
end
