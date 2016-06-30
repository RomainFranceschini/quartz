module DEVS
  # The {Coupleable} mixin provides models with the ability to be coupled
  # through an input and output interface.
  module Coupleable
    getter  :input_port_list, :output_port_list, :input_port_names, :output_port_names

    def input_ports : Hash(Symbol | String, Port)
      @input_ports ||= Hash(Symbol | String, Port).new
    end

    def output_ports : Hash(Symbol | String, Port)
      @output_ports ||= Hash(Symbol | String, Port).new
    end

    @output_port_names : Array(Symbol|String)?
    @input_port_names : Array(Symbol|String)?
    @input_port_list : Array(Port)?
    @output_port_list : Array(Port)?

    # Adds an input port to *self*.
    def add_input_port(*names)
      @input_port_names = nil; @input_port_list = nil; # cache invalidation
      add_ports(IO::Input, *names)
    end

    # Adds an output port to *self*.
    def add_output_port(*names)
      @output_port_names = nil; @output_port_list = nil; # cache invalidation
      add_ports(IO::Output, *names)
    end

    def remove_input_port(name)
      @input_port_names = nil; @input_port_list = nil; # cache invalidation
      input_ports.delete(name)
    end

    def remove_output_port(name)
      @output_port_names = nil; @output_port_list = nil; # cache invalidation
      output_ports.delete(name)
    end

    # Returns the list of input ports' names
    def input_port_names
      @input_port_names ||= @input_ports.keys
    end

    # Returns the list of output ports' names
    def output_port_names
      @output_port_names ||= @output_ports.keys
    end

    # Returns the list of input ports
    def input_port_list : Array(Port)
      @input_port_list ||= @input_ports.values
    end

    # Returns the list of output ports
    def output_port_list : Array(Port)
      @output_port_list ||= @output_ports.values
    end

    # Find the input port identified by the given *name*.
    def input_port?(name : String|Symbol) : Port?
      input_ports[name]?
    end

    # Find the input port identified by the given *name*.
    def input_port(name : String|Symbol) : Port
      raise NoSuchPortError.new unless input_ports.has_key?(name)
      input_ports[name]
    end

    # Find the output port identified by the given *name*
    def output_port?(name : String|Symbol) : Port?
      output_ports[name]?
    end

    # Find the output port identified by the given *name*
    def output_port(name : String|Symbol) : Port
      raise NoSuchPortError.new unless output_ports.has_key?(name)
      output_ports[name]
    end

    # Find or create an input port if necessary. If the given argument is nil,
    # an input port is created with a default name. Otherwise, an attempt to
    # find the matching port is made. If the given port doesn't exists, it is
    # created with the given name.
    protected def find_or_create_input_port_if_necessary(port : Port | Symbol | String) : Port
      find_or_create_port_if_necessary(IO::Input, port)
    end

    # Find or create an output port if necessary. If the given argument is nil,
    # an output port is created with a default name. Otherwise, an attempt to
    # find the matching port is made. If the given port doesn't exists, it is
    # created with the given name.
    #
    # @param port [String, Symbol] the output port name
    # @return [Port] the matching port or the newly created port
    protected def find_or_create_output_port_if_necessary(port : Port | Symbol | String) : Port
      find_or_create_port_if_necessary(IO::Output, port)
    end

    private def find_or_create_port_if_necessary(mode : IO, port : Port | Symbol | String) : Port
      unless port.is_a?(Port)
        name = port
        port = if mode.output?
          output_ports[name]?
        else
          input_ports[name]?
        end

        if port.nil?
          port = add_port(mode, name)
          DEVS.logger.warn("specified #{mode} port #{name} doesn't exist for #{self}. creating it") if DEVS.logger
        end
      end
      port
    end

    private def add_ports(mode : IO, *names) : Array(Port)
      case mode
      when IO::Input
        ports = input_ports
      else
        ports = output_ports
      end

      new_ports = [] of Port
      names.each do |n|
        if ports.has_key?(n)
          DEVS.logger.warn(
            "specified #{mode} port #{n} already exists for #{self}. skipping..."
          ) if DEVS.logger
          new_ports << ports[n]
        else
          p = Port.new(self, mode, n)
          ports[n] = p
          new_ports << p
        end
      end

      new_ports
    end

    private def add_port(mode : IO, port_name : Symbol | String) : Port
      case mode
      when IO::Input
        ports = input_ports
      else
        ports = output_ports
      end

      if ports.has_key?(port_name)
        DEVS.logger.warn(
          "specified #{mode} port #{port_name} already exists for #{self}. skipping..."
        ) if DEVS.logger

        new_port = ports[port_name]
      else
        new_port = Port.new(self, mode, port_name)
        ports[port_name] = new_port
      end

      new_port
    end
  end
end
