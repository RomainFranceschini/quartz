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

  # :nodoc:
  abstract class InPort < Port
    getter(downward_ports) { Array(InPort).new }
  end

  # :nodoc:
  abstract class OutPort < Port
    getter(siblings_ports) { Array(InPort).new }
    getter(upward_ports) { Array(OutPort).new }
  end

  # This class represents an input port that belongs to a `Coupleable` (the *host*).
  class InputPort(T) < InPort
  end

  # This class represents an output port that belongs to a `Coupleable` (the *host*).
  class OutputPort(T) < OutPort
    include Observable

    # :nodoc:
    property! value : T

    # TODO if port is input, check downward ports until find an atomic input port
    # if port is output, check in reverse upward ports until find an atomic output port
    def add_observer(observer)
      if @host.is_a?(CoupledModel)
        @host.as(CoupledModel).each_output_coupling_reverse(self) do |src, _|
          src.add_observer(observer)
        end
      else
        super(observer)
      end
    end
  end
end
