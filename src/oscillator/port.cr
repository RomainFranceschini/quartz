module DEVS
  # A `Port` may be configured as an Input or Output IO mode.
  enum IO
    Input
    Output
  end

  # This class represents a port that belongs to a `Model` (the *host*).
  class Port
    include Observable(PortObserver)

    getter :type, :name, :host

    # Returns a new `Port` instance, owned by *host*
    def initialize(@host : Coupleable, @mode : IO, @name : Symbol | String); end

    def add_observer(observer : PortObserver)
      raise UnobservablePortError.new("Atomic models output ports only are observable.") if @mode == IO::Input || @host.is_a?(CoupledModel)
      super(observer)
    end

    # Check if *self* is an input port
    def input?
      @mode == IO::Input
    end

    # Check if *self* is an output port
    def output?
      @mode == IO::Output
    end

    def to_s
      @name.to_s
    end

    def inspect
      "<#{self.class}: name=#{@name}, type=#{@mode}, host=#{@host.name}>"
    end
  end
end
