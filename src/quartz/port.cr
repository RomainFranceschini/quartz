module Quartz
  # Represents a port that belongs to a `Coupleable` (the *host*).
  abstract class Port
    getter name : Name
    getter host : Coupleable

    def_hash @name, @host

    def initialize(@host : Coupleable, @name : Name)
    end

    def to_s(io)
      io << @name
      nil
    end
  end

  # This class represents an input port that belongs to a `Coupleable` (the *host*).
  class InputPort < Port
    getter(downward_ports) { Array(InputPort).new }
  end

  # This class represents an output port that belongs to a `Coupleable` (the *host*).
  class OutputPort < Port
    getter(peers_ports) { Array(InputPort).new }
    getter(upward_ports) { Array(OutputPort).new }

    include Observable

    def add_observer(observer)
      if @host.is_a?(CoupledModel)
        raise UnobservablePortError.new("Only atomic models output ports are observable.")
      end
      super(observer)
    end
  end
end
