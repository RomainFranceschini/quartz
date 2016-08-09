module DEVS
  # A `Port` may be configured as an Input or Output IO mode.
  enum IOMode
    Input
    Output
  end

  # This class represents a port that belongs to a `Model` (the *host*).
  class Port
    include Comparable(Port)
    include Observable(PortObserver)

    getter mode : IOMode
    getter name : Name
    getter host : Coupleable

    # Returns a new `Port` instance, owned by *host*
    def initialize(@host : Coupleable, @mode : IOMode, @name : Name)
    end

    def add_observer(observer : PortObserver)
      if @mode == IOMode::Input || @host.is_a?(CoupledModel)
        raise UnobservablePortError.new("Only atomic models output ports are observable.")
      end
      super(observer)
    end

    # Check if *self* is an input port
    def input?
      @mode == IOMode::Input
    end

    # Check if *self* is an output port
    def output?
      @mode == IOMode::Output
    end

    def to_s(io)
      io << @name
    end

    def ==(other : Port)
      @mode == other.mode && @name == other.name && @host == other.host
    end

    # :nodoc:
    def ==(other)
      false
    end

    def hash
      res = 31 * 17 + @mode.hash
      res = 31 * res + @name.hash
      31 * res + @host.hash
    end
  end
end
