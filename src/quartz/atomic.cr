module Quartz
  # This class represent a PDEVS atomic model.
  abstract class AtomicModel < Model
    include Coupleable
    include Observable
    include Verifiable
    include AutoState

    # The precision associated with the model.
    class_property precision_level : Scale = Scale::BASE

    # Defines the precision level associated to this class of models.
    #
    # ### Usage:
    #
    # `precision` must receive a scale unit. The scale unit can be specified
    # with a constant expression (e.g. 'kilo'), with a `Scale` struct or with
    # a number literal.
    #
    # ```
    # precision Scale.::KILO
    # precision -8
    # precision femto
    # ```
    #
    # If specified with a constant expression, the unit argument can be a string
    # literal, a symbol literal or a plain name.
    #
    # ```
    # precision kilo
    # precision "kilo"
    # precision :kilo
    # ```
    #
    # ### Example
    #
    # ```
    # class MyModel < Quartz::AtomicModel
    #   precision femto
    # end
    # ```
    #
    # Is the same as writing:
    #
    # ```
    # class MyModel < Quartz::AtomicModel
    #   self.precision = Scale::FEMTO
    # end
    # ```
    #
    # Or the same as:
    #
    # ```
    # class MyModel < Quartz::AtomicModel; end
    #
    # MyModel.precision = Scale::FEMTO
    # ```
    private macro precision(scale = "base")
      {% if Quartz::ALLOWED_SCALE_UNITS.includes?(scale.id.stringify) %}
        self.precision_level = Quartz::Scale::{{ scale.id.upcase }}
      {% elsif scale.is_a?(NumberLiteral) %}
        self.precision_level = Quartz::Scale.new({{scale}})
      {% else %}
        self.precision_level = {{scale}}
      {% end %}
    end

    # Returns the precision associated with the class.
    def model_precision : Scale
      @@precision_level
    end

    # This attribute is updated automatically along simulation and represents
    # the elapsed time since the last transition.
    property elapsed : Duration = Duration.zero(@@precision_level)

    def initialize(name)
      super(name)
      @bag = SimpleHash(OutputPort, Any).new
      @elapsed = @elapsed.rescale(@@precision_level)
    end

    def initialize(name, state)
      super(name)
      @bag = SimpleHash(OutputPort, Any).new
      @elapsed = @elapsed.rescale(@@precision_level)
      self.initial_state = state
      self.state = state
    end

    # The external transition function (δext)
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def external_transition(messages)
    #   messages.each { |port, value|
    #     puts "#{port} => #{value}"
    #   }
    # end
    # ```
    abstract def external_transition(messages : Hash(InputPort, Array(Any)))

    # Internal transition function (δint), called when the model should be
    # activated, e.g when `#elapsed` reaches `#time_advance`
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def internal_transition
    #   self.phase = :steady
    # end
    # ```
    abstract def internal_transition

    # This is the default definition of the confluent transition. Here the
    # internal transition is allowed to occur and this is followed by the
    # effect of the external transition on the resulting state.
    #
    # Override this method to obtain a different behavior. For example, the
    # opposite order of effects (external transition before internal
    # transition). Of course you can override without reference to the other
    # transitions.
    def confluent_transition(messages : Hash(InputPort, Array(Any)))
      internal_transition
      external_transition(messages)
    end

    # Time advance function (ta), called after each transition to give a
    # chance to *self* to be active.
    #
    # Override this method to implement the appropriate behavior of
    # your model.
    #
    # Example:
    # ```
    # def time_advance
    #   Quartz.infinity
    # end
    # ```
    abstract def time_advance : Duration

    # The output function (λ)
    #
    # Override this method to implement the appropriate behavior of
    # your model. See `#post` to send values to output ports.
    #
    # Example:
    # ```
    # def output
    #   post(42, :output)
    # end
    abstract def output

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
      @elapsed = Duration.new(0, @@precision_level)

      pull.read_object do |key|
        case key
        when "name"
          super(String.new(pull))
        when "state"
          self.initial_state = {{ (@type.name + "::State").id }}.new(pull)
          self.state = initial_state
        else
          raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
        end
      end
    end

    def initialize(pull : ::MessagePack::Unpacker)
      @bag = SimpleHash(OutputPort, Any).new

      pull.read_hash(false) do
        case key = Bytes.new(pull)
        when "name".to_slice
          super(String.new(pull))
        when "state".to_slice
          self.initial_state = {{ (@type.name + "::State").id }}.new(pull)
          self.state = initial_state
        else
          raise MessagePack::UnpackException.new("unknown msgpack attribute: #{String.new(key)}")
        end
      end
    end

    def inspect(io)
      io << "<" << self.class.name << ": name=" << @name
      io << ", elapsed=" << @elapsed.to_s(io)
      io << ">"
      nil
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an `InvalidPortHostError` if the given port doesn't belong to this
    # model.
    protected def post(value : Any::Type, on : OutputPort)
      post(Any.new(value), on)
    end

    # Drops off an output *value* to the specified output *port*.
    #
    # Raises an `InvalidPortHostError` if the given port doesn't belong to this
    # model.
    # Raises an `NoSuchPortError` if the given output port doesn't exists.
    @[AlwaysInline]
    protected def post(value : Any::Type, on : Name)
      post(Any.new(value), self.output_port(on))
    end

    protected def post(value : Any, on : OutputPort)
      raise InvalidPortHostError.new("Given port doesn't belong to this model") if on.host != self
      @bag.unsafe_assoc(on, value)
    end

    protected def post(value : Any, on : Name)
      post(value, self.output_port(on))
    end

    # :nodoc:
    #
    # Returns outgoing messages added by the DEVS lambda (λ) function for the
    # current state.
    #
    # This method calls the DEVS lambda (λ) function
    # Note: this method should be called only by the simulator.
    def fetch_output! : SimpleHash(OutputPort, Any)
      @bag.clear
      self.output
      @bag
    end

    def to_json(json : ::JSON::Builder)
      json.object do
        json.field("name") { @name.to_json(json) }
        json.field("state") { state.to_json(json) }
      end
    end

    def to_msgpack(packer : ::MessagePack::Packer)
      packer.write_hash_start(2)

      packer.write("name")
      @name.to_msgpack(packer)
      packer.write("state")
      state.to_msgpack(packer)
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
