module Quartz
  # This class represent a PDEVS atomic model.
  class AtomicModel < Model
    include Coupleable
    include Transitions
    include Observable
    include Verifiable
    include AutoState

    def initialize(name)
      super(name)
      @senders = Set(OutPort).new
    end

    def initialize(name, state)
      super(name)
      @bag = SimpleHash(OutputPort, Any).new
      self.initial_state = state
      self.state = state
    end

    # :nodoc:
    # Used internally by the simulator
    def __initialize_state__(processor)
      if @processor != processor
        raise InvalidProcessorError.new("trying to initialize state of model \"#{name}\" from an invalid processor")
      end

      if s = initial_state
        self.state = s
      end
    end

    def initialize(pull : ::JSON::PullParser)
      @bag = SimpleHash(OutputPort, Any).new
      _sigma = INFINITY
      _time = -INFINITY

      pull.read_object do |key|
        case key
        when "name"
          super(String.new(pull))
        when "sigma"
          _sigma = SimulationTime.new(pull)
        when "time"
          _time = SimulationTime.new(pull)
        when "state"
          self.initial_state = {{ (@type.name + "::State").id }}.new(pull)
          self.state = initial_state
        else
          raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
        end
      end

      @sigma = _sigma
      @time = _time
    end

    def initialize(pull : ::MessagePack::Unpacker)
      @bag = SimpleHash(OutputPort, Any).new
      _sigma = INFINITY
      _time = -INFINITY

      pull.read_hash(false) do
        case key = Bytes.new(pull)
        when "name".to_slice
          super(String.new(pull))
        when "sigma".to_slice
          _sigma = SimulationTime.new(pull)
        when "time".to_slice
          _time = SimulationTime.new(pull)
        when "state".to_slice
          self.initial_state = {{ (@type.name + "::State").id }}.new(pull)
          self.state = initial_state
        else
          raise MessagePack::UnpackException.new("unknown msgpack attribute: #{String.new(key)}")
        end
      end

      @sigma = _sigma
      @time = _time
    end

    def inspect(io)
      io << "<" << self.class.name << ": name=" << @name
      io << ", time=" << @time.to_s(io)
      io << ", elapsed=" << @elapsed.to_s(io)
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

    def to_json(json : ::JSON::Builder)
      json.object do
        json.field("name") { @name.to_json(json) }
        json.field("state") { state.to_json(json) }
        json.field("time") { @time.to_json(json) } unless @time.abs == INFINITY
        json.field("sigma") { @sigma.to_json(json) } unless @sigma.abs == INFINITY
      end
    end

    def to_msgpack(packer : ::MessagePack::Packer)
      packer.write_hash_start(4)

      packer.write("name")
      @name.to_msgpack(packer)
      packer.write("state")
      state.to_msgpack(packer)
      packer.write("time")
      @time.to_msgpack(packer)
      packer.write("sigma")
      @sigma.to_msgpack(packer)
    end

    def self.from_json(io : IO)
      self.new(::JSON::PullParser.new(io))
    end

    def self.from_json(str : String)
      from_json(IO::Memory.new(str))
    end

    def self.from_msgpack(io : IO)
      self.new(::MessagePack::Unpacker.new(io))
    end

    def self.from_msgpack(bytes : Bytes)
      from_msgpack(IO::Memory.new(bytes))
    end
  end
end
