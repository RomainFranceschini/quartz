module DEVS
  # This class represent a DEVS atomic model.
  class AtomicModel < Model
    include Coupleable
    include Behavior
    include Observable(TransitionObserver)

    # TODO fixme when introducing cdevs
    def self.processor_for(namespace)
      # case namespace
      # when PDEVS
      #   PDEVS::Simulator
      # else
      #   CDEVS::Simulator
      # end
      PDEVS::Simulator
    end

    # Returns a new instance of {AtomicModel}
    #
    # @param name [String, Symbol] the name of the model
    def initialize(name)
      super(name)
      #@bag = {} of Port => Type
      @bag = {} of Port => Any
    end

    def inspect
      "<#{self.class}: name=#{@name}, time=#{@time}, elapsed=#{@elapsed}>"
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an InvalidPortHostError if the given port doesn't belong to this
    # model.
    # Raises an InvalidPortModeError if the given port is not an output port.
    protected def post(value : Type, port : Port)
      raise InvalidPortHostError.new("Given port doesn't belong to this model") if port.host != self
      raise InvalidPortModeError.new("Given port should be an output port") if port.input?
      @bag[port] = Any.new(value)
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an InvalidPortHostError if the given port doesn't belong to this
    # model.
    # Raises an InvalidPortModeError if the given port is not an output port.
    # Raises an NoSuchChildError if the given port doesn't exists.
    protected def post(value : Type, port_name : String|Symbol)
      post(value, self.output_port(port_name))
    end

    # TODO change API to return NamedTuple ?
    # Returns outgoing messages added by the DEVS lambda (λ) function for the
    # current state.
    #
    # This method calls the DEVS lambda (λ) function
    # Note: this method should be called only by the simulator.
    def fetch_output! : Hash(Port, Any) #Hash(Port,Type)
      @bag.clear
      self.output
      @bag
    end
  end
end
