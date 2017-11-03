module Quartz
  # The `Coupleable` mixin provides models with the ability to be coupled with
  # other coupleables through an input and output interface.
  module Coupleable
    include Transferable

    @input_ports : Hash(Name, InPort)?
    @output_ports : Hash(Name, OutPort)?

    macro included
      {% if !@type.has_constant? :INPUT_PORTS %}
        INPUT_REGISTRY = [] of _
        OUTPUT_REGISTRY = [] of _
      {% end %}

      # Defines default input ports for each of the given arguments.
      # Those default input ports will be available in all instances, including
      # instances of subclasses (meaning that ports are inherited).
      #
      # Writing:
      #
      # ```
      # class MyModel < AtomicModel
      #   input port_name
      # end
      # ```
      #
      # Is the same as writing:
      #
      # ```
      # class MyModel < AtomicModel
      #   def initialize(name)
      #     super(name)
      #     add_input_port :port_name
      #   end
      # end
      # ```
      #
      # The arguments can be string literals, symbol literals or plain names.
      # However, they will be converted to symbol literals when the
      # model is instantiated.
      #
      # ```
      # class MyModel < AtomicModel
      #   input :in1, "in2", in3
      # end
      # ```
      macro input(*portsdef)
        \{% for portdef in portsdef %}
          \{% if portdef.is_a?(TypeDeclaration) %}
            \{% INPUT_REGISTRY << {name: portdef.var, type: portdef.type} %}
          \{% else %}
            \{% INPUT_REGISTRY << {name: portdef.id, type: Type} %}
          \{% end %}
        \{% end %}
      end

      # Defines default output ports for each of the given arguments.
      # Those default output ports will be available in all instances, including
      # instances of subclasses (meaning that ports are inherited).
      #
      # Writing:
      #
      # ```
      # class MyModel < AtomicModel
      #   output port_name
      # end
      # ```
      #
      # Is the same as writing:
      #
      # ```
      # class MyModel < AtomicModel
      #   def initialize(name)
      #     super(name)
      #     add_output_port :port_name
      #   end
      # end
      # ```
      #
      # The arguments can be string literals, symbol literals or plain names.
      # However, they will be converted to symbols literals when the
      # model is instantiated.
      #
      # ```
      # class MyModel < AtomicModel
      #   output :out1, "out2", out3
      # end
      # ```
      macro output(*portsdef)
        \{% for portdef in portsdef %}
          \{% if portdef.is_a?(TypeDeclaration) %}
            \{% OUTPUT_REGISTRY << {name: portdef.var, type: portdef.type} %}
          \{% else %}
            \{% OUTPUT_REGISTRY << {name: portdef.id, type: Type} %}
          \{% end %}
        \{% end %}
      end

      # Copy ports on inheritance.
      macro inherited
        \{% puts "#{@type} inherits #{@type.superclass}" %}

        \{% puts INPUT_REGISTRY %}

        \{% if INPUT_REGISTRY.empty? %}
          \{% for port in INPUT_REGISTRY %}
            input \{{ port[:name] }} : \{{ port[:type] }}
          \{% end %}
        \{% else %}
          INPUT_REGISTRY = [] of _
        \{% end %}

        \{% if OUTPUT_REGISTRY.empty? %}
          \{% for port in OUTPUT_REGISTRY %}
            output \{{ port[:name] }} : \{{ port[:type] }}
          \{% end %}
        \{% else %}
          OUTPUT_REGISTRY = [] of _
        \{% end %}
      end

    end

    # :nodoc:
    protected def input_ports # : Hash(Name, InPort)
      @input_ports ||= (
        iports = Hash(Name, InPort).new
        {{ puts "#{@type} output #{@type.constant(:INPUT_REGISTRY)}" }}
        {% for port in @type.constant(:INPUT_REGISTRY) %}
          iports[:{{ port[:name] }}] = InputPort({{port[:type]}}).new(self, :{{ port[:name] }})
        {% end %}
        iports
      )
    end

    # :nodoc:
    protected def output_ports # : Hash(Name, OutPort)
      @output_ports ||= (
        oports = Hash(Name, OutPort).new
        {% for port in @type.constant(:OUTPUT_REGISTRY) %}
          {% if port[:type] == Type %}
            oports[:{{ port[:name] }}] = OutputPort(Type).new(self, :{{ port[:name] }})
          {% else %}
            oports[:{{ port[:name] }}] = OutputPort({{port[:type]}}).new(self, :{{ port[:name] }})
          {% end %}
        {% end %}
        oports
      )
    end

    # Add given port to *self*.
    def add_port(port : InputPort(Type))
      raise InvalidPortHostError.new if port.host != self
      input_ports[port.name] = port
    end

    # Add given port to *self*.
    def add_port(port : OutputPort(Type))
      raise InvalidPortHostError.new if port.host != self
      output_ports[port.name] = port
    end

    # Add given input port to *self*.
    def add_input_port(name, type : T.class) : InputPort(T) forall T
      if input_ports.has_key?(name)
        Quartz.logger?.try &.warn(
          "specified input port #{name} already exists for #{self}. skipping..."
        )

        new_port = input_ports[name].as(InputPort(T))
      else
        new_port = InputPort(T).new(self, name)
        self.add_port(new_port)
      end

      new_port
    end

    # Add given input port to *self*.
    def add_input_port(name) : InputPort(Type)
      if input_ports.has_key?(name)
        Quartz.logger?.try &.warn(
          "specified input port #{name} already exists for #{self}. skipping..."
        )

        new_port = input_ports[name].as(InputPort(Type))
      else
        new_port = InputPort(Type).new(self, name)
        self.add_port(new_port)
      end

      new_port
    end

    # Add given output port to *self*.
    def add_output_port(name, type : T.class) : OutputPort(T) forall T
      if output_ports.has_key?(name)
        Quartz.logger?.try &.warn(
          "specified output port #{name} already exists for #{self}. skipping..."
        )

        new_port = output_ports[name].as(OutputPort(T))
      else
        new_port = OutputPort(T).new(self, name)
        self.add_port(new_port)
      end

      new_port
    end

    # Add given output port to *self*.
    def add_output_port(name) : OutputPort(Type)
      if output_ports.has_key?(name)
        Quartz.logger?.try &.warn(
          "specified output port #{name} already exists for #{self}. skipping..."
        )

        new_port = output_ports[name].as(OutputPort(Type))
      else
        new_port = OutputPort(Type).new(self, name)
        self.add_port(new_port)
      end

      new_port
    end

    # Removes given input *port* from *self*.
    def remove_port(port : InputPort)
      input_ports.delete(port.name)
    end

    # Removes given output *port* from *self*.
    def remove_port(port : OutputPort)
      output_ports.delete(port.name)
    end

    # Removes given input port by its *name*.
    def remove_input_port(name)
      input_ports.delete(name)
    end

    # Removes given output port by its *name*.
    def remove_output_port(name)
      output_ports.delete(name)
    end

    # Returns the list of input ports' names
    def input_port_names
      input_ports.keys
    end

    # Returns the list of output ports' names
    def output_port_names
      output_ports.keys
    end

    # Returns the list of input ports
    def input_port_list # : Array(InPort)
      input_ports.values
    end

    # Returns the list of output ports
    def output_port_list # : Array(OutPort)
      output_ports.values
    end

    # Calls given block once for each input port, passing that element as a
    # parameter.
    def each_input_port
      input_ports.each_value { |port| yield(port) }
    end

    # :nodoc:
    def each_input_port
      input_ports.each_value
    end

    # Calls given block once for each output port, passing that element as a
    # parameter.
    def each_output_port
      output_ports.each_value { |port| yield(port) }
    end

    # :nodoc:
    def each_output_port
      output_ports.each_value
    end

    # Find the input port identified by the given *name*.
    def input_port?(name : Name) # : InPort?
      input_ports[name]?
    end

    # Find the input port identified by the given *name*.
    def input_port(name : Name) # : InPort
      raise NoSuchPortError.new("input port \"#{name}\" not found") unless input_ports.has_key?(name)
      input_ports[name]
    end

    # Find the output port identified by the given *name*
    def output_port?(name : Name) # : OutPort?
      output_ports[name]?
    end

    # Find the output port identified by the given *name*
    def output_port(name : Name) # : OutPort
      raise NoSuchPortError.new("output port \"#{name}\" not found") unless output_ports.has_key?(name)
      output_ports[name]
    end

    # Find or create an input port if necessary. If the given argument is nil,
    # an input port is created with given name. Otherwise, an attempt to
    # find the matching port is made. If the given port doesn't exists, it is
    # created with the given name.
    protected def find_or_create_input_port_if_necessary(port_name : Name) : InputPort(Type)
      port = input_ports[port_name]?
      if port.nil?
        port = add_input_port(port_name, Type)
        Quartz.logger?.try &.warn("specified input port #{port_name} doesn't exist for #{self}. creating it with type Type.")
      end
      port.as(InputPort(Type))
    end

    # Find or create an output port if necessary. If the given argument is nil,
    # an output port is created with given name. Otherwise, an attempt to
    # find the matching port is made. If the given port doesn't exists, it is
    # created with the given name.
    protected def find_or_create_output_port_if_necessary(port_name : Name) : OutputPort(Type)
      port = output_ports[port_name]?
      if port.nil?
        port = add_output_port(port_name, Type)
        Quartz.logger?.try &.warn("specified output port #{port_name} doesn't exist for #{self}. creating it with type Type.")
      end
      port.as(OutputPort(Type))
    end
  end
end
