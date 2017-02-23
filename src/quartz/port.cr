module Quartz
  # A `Port` may be configured as an Input or Output IO mode.
  enum IOMode
    Input
    Output
  end

  # This class represents a port that belongs to a `Model` (the *host*).
  class Port
    include Observable

    getter mode : IOMode
    getter name : Name
    getter host : Coupleable

    def_hash @name, @mode, @host

    delegate output?, to: @mode
    delegate input?, to: @mode

    # Returns a new `Port` instance, owned by *host*
    def initialize(@host : Coupleable, @mode : IOMode, @name : Name)
    end

    def add_observer(observer)
      if @mode == IOMode::Input || @host.is_a?(CoupledModel)
        raise UnobservablePortError.new("Only atomic models output ports are observable.")
      end
      super(observer)
    end

    def to_s(io)
      io << @name
      nil
    end
  end
end
