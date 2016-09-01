module Quartz
  # The `Coupleable` mixin provides models with the ability to be coupled
  # through an input and output interface.
  module Coupleable
    protected def input_ports : Hash(Name, Port)
      @input_ports ||= Hash(Name, Port).new
    end

    protected def output_ports : Hash(Name, Port)
      @output_ports ||= Hash(Name, Port).new
    end

    # Add given port to *self*.
    def add_port(port : Port)
      case port.mode
      when IOMode::Input
        input_ports[port.name] = port
      when IOMode::Output
        output_ports[port.name] = port
      end
    end

    # Add given input port to *self*.
    def add_input_port(name)
      add_port(IOMode::Input, name)
    end

    # Add given output port to *self*.
    def add_output_port(name)
      add_port(IOMode::Output, name)
    end

    # Removes given *port* from *self*.
    def remove_port(port : Port)
      case port.mode
      when IOMode::Input
        input_ports.delete(port.name)
      when IOMode::Output
        output_ports.delete(port.name)
      end
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
    def input_port_list : Array(Port)
      input_ports.values
    end

    # Returns the list of output ports
    def output_port_list : Array(Port)
      output_ports.values
    end

    # Find the input port identified by the given *name*.
    def input_port?(name : Name) : Port?
      input_ports[name]?
    end

    # Find the input port identified by the given *name*.
    def input_port(name : Name) : Port
      raise NoSuchPortError.new("input port \"#{name}\" not found") unless input_ports.has_key?(name)
      input_ports[name]
    end

    # Find the output port identified by the given *name*
    def output_port?(name : Name) : Port?
      output_ports[name]?
    end

    # Find the output port identified by the given *name*
    def output_port(name : Name) : Port
      raise NoSuchPortError.new("output port \"#{name}\" not found") unless output_ports.has_key?(name)
      output_ports[name]
    end

    # Find or create an input port if necessary. If the given argument is nil,
    # an input port is created with given name. Otherwise, an attempt to
    # find the matching port is made. If the given port doesn't exists, it is
    # created with the given name.
    protected def find_or_create_input_port_if_necessary(port : Name) : Port
      find_or_create_port_if_necessary(IOMode::Input, port)
    end

    # Find or create an output port if necessary. If the given argument is nil,
    # an output port is created with given name. Otherwise, an attempt to
    # find the matching port is made. If the given port doesn't exists, it is
    # created with the given name.
    protected def find_or_create_output_port_if_necessary(port : Name) : Port
      find_or_create_port_if_necessary(IOMode::Output, port)
    end

    # :nodoc:
    private def find_or_create_port_if_necessary(mode : IOMode, port_name : Name) : Port
      port = if mode.output?
        output_ports[port_name]?
      else
        input_ports[port_name]?
      end

      if port.nil?
        port = add_port(mode, port_name)
        Quartz.logger.warn("specified #{mode} port #{port_name} doesn't exist for #{self}. creating it") if Quartz.logger
      end

      port
    end

    # :nodoc:
    private def add_port(mode : IOMode, port_name : Name) : Port
      case mode
      when IOMode::Input
        ports = input_ports
      else
        ports = output_ports
      end

      if ports.has_key?(port_name)
        Quartz.logger.warn(
          "specified #{mode} port #{port_name} already exists for #{self}. skipping..."
        ) if Quartz.logger

        new_port = ports[port_name]
      else
        new_port = Port.new(self, mode, port_name)
        ports[port_name] = new_port
      end

      new_port
    end
  end
end
