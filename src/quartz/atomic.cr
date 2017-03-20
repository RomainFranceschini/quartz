module Quartz
  # This class represent a PDEVS atomic model.
  class AtomicModel < Model
    include Coupleable
    include Transitions
    include Observable
    include Validations

    def initialize(name)
      super(name)
      @bag = SimpleHash(Port, Any).new
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
    # Raises an InvalidPortHostError if the given port doesn't belong to this
    # model.
    # Raises an InvalidPortModeError if the given port is not an output port.
    protected def post(value : Type, on : Port)
      raise InvalidPortHostError.new("Given port doesn't belong to this model") if on.host != self
      raise InvalidPortModeError.new("Given port should be an output port") if on.input?
      @bag.unsafe_assoc(on, Any.new(value))
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an InvalidPortHostError if the given port doesn't belong to this
    # model.
    # Raises an InvalidPortModeError if the given port is not an output port.
    # Raises an NoSuchPortError if the given port doesn't exists.
    @[AlwaysInline]
    protected def post(value : Type, on : Name)
      post(value, self.output_port(on))
    end

    # :nodoc:
    #
    # Returns outgoing messages added by the DEVS lambda (λ) function for the
    # current state.
    #
    # This method calls the DEVS lambda (λ) function
    # Note: this method should be called only by the simulator.
    def fetch_output! : SimpleHash(Port, Any)
      @bag.clear
      self.output
      @bag
    end
  end
end