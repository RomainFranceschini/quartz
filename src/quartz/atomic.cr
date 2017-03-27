module Quartz
  # This class represent a PDEVS atomic model.
  class AtomicModel < Model
    include Coupleable
    include Transitions
    include Observable
    include Validations

    def initialize(name)
      super(name)
      @senders = Set(OutPort).new
    end

    def inspect(io)
      io << "<" << self.class.name << ": name=" << @name
      io << ", time=" << @time.to_s(io)
      io << ", elapsed" << @elapsed.to_s(io)
      io << ">"
      nil
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an `InvalidPortHostError` if the given port doesn't belong to this
    # model.
    protected def post(value : U, on : OutputPort(T)) forall T, U
      {% unless T >= U || (T.union? && T.union_types.includes?(U))
        raise "Type mismatch. Can't post #{U} on OutputPort(#{T})."
      end %}

      if on.host != self
        raise InvalidPortHostError.new("Given port doesn't belong to this model")
      end
      on.value = value
      @senders << on
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an `InvalidPortHostError` if the given port doesn't belong to this
    # model.
    # Raises an `NoSuchPortError` if the given output port doesn't exists.
    @[AlwaysInline]
    protected def post(value : Type, on : Name)
      unless self.output_ports.has_key?(on)
        raise InvalidPortHostError.new("Specified port name doesn't belong to this model")
      end

      port = self.output_port(on)
      port.value = value
      #port.as(OutputPort(T)).value = value
      @senders << port
    end

    # :nodoc:
    #
    # Returns outgoing messages added by the DEVS lambda (λ) function for the
    # current state.
    #
    # This method calls the DEVS lambda (λ) function
    # Note: this method should be called only by the simulator.
    def fetch_output! : SimpleHash(OutPort, Any)
      @senders.clear
      self.output
      bag = SimpleHash(OutPort, Any).new
      @senders.each do |port|
        bag[port] = Any.new(port.value)
      end
      bag
    end
  end
end
