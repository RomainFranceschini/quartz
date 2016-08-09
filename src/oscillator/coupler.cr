module DEVS
  # This mixin provides coupled models with several components and
  # coupling methods.
  module Coupler

    @children : Hash(Name, Model)?
    @internal_couplings : Hash(Port,Array(Port))?
    @output_couplings : Hash(Port,Array(Port))?
    @input_couplings : Hash(Port,Array(Port))?

    # :nodoc:
    protected def children : Hash(Name, Model)
      @children ||= Hash(Name, Model).new
    end

    # :nodoc:
    protected def internal_couplings : Hash(Port,Array(Port))
      @internal_couplings ||= Hash(Port,Array(Port)).new { |h, k| h[k] = Array(Port).new }
    end

    # :nodoc:
    protected def output_couplings : Hash(Port,Array(Port))
      @output_couplings ||= Hash(Port,Array(Port)).new { |h, k| h[k] = Array(Port).new }
    end

    # :nodoc:
    protected def input_couplings : Hash(Port,Array(Port))
      @input_couplings ||= Hash(Port,Array(Port)).new { |h, k| h[k] = Array(Port).new }
    end

    # Returns all internal couplings attached to the given output *port*.
    def internal_couplings(port : Port) : Array(Port)
      internal_couplings[port]
    end

    # Returns all external output couplings attached to the given output *port*.
    def output_couplings(port : Port) : Array(Port)
      output_couplings[port]
    end

    # Returns all external input couplings attached to the given input *port*.
    def input_couplings(port : Port) : Array(Port)
      input_couplings[port]
    end

    # Append the given *model* to childrens
    def <<(model : Model)
      children[model.name] = model
      self
    end

    # Alias for `#<<`.
    def add_child(child); self << child; end

    # Deletes the given *model* from childrens
    def remove_child(model : Model)
      children.delete(model.name)
    end

    # Returns the children names
    def children_names : Array(Name)
      children.keys
    end

    # Find the component identified by the given *name*
    #
    # Raise `NoSuchChildError` error if *name* doesn't match any child
    def [](name : Name) : Model
      raise NoSuchChildError.new("no child named #{name}") unless children.has_key?(name)
      children[name]
    end

    # Find the component identified by the given *name*
    def []?(name : Name) : Model?
      children[name]?
    end

    # Returns whether given *model* is a child of *self*
    def has_child?(model : Model) : Bool
      children.has_key?(model.name)
    end

    # Returns whether *self* has a child named like *name*
    def has_child?(name : Name) : Bool
      children.has_key?(name)
    end

    # Calls given block once for each child, passing that
    # element as a parameter.
    def each_child
      children.each_value { |child| yield child }
    end

    # Returns an `Iterator` for the children of `self`
    def each_child
      children.each_value
    end

    # Calls *block* once for each external input coupling (EIC) in
    # `#input_couplings`, passing that element as a parameter. Given *port* is
    # used to filter couplings having this port as a source.
    def each_input_coupling(port : Port)
      input_couplings[port].each { |dst| yield(port, dst) }
    end

    # Calls *block* once for each external input coupling (EIC) in
    # `#input_couplings`, passing that element as a parameter.
    def each_input_coupling
      input_couplings.each { |src,ary| ary.each { |dst| yield(src,dst) }}
    end

    # Calls *block* once for each internal coupling (IC) in
    # `#internal_couplings`, passing that element as a parameter. Given *port*
    # is used to filter couplings having this port as a source.
    def each_internal_coupling(port : Port)
      internal_couplings[port].each { |dst| yield(port, dst) }
    end

    # Calls *block* once for each internal coupling (IC) in
    # `#internal_couplings`, passing that element as a parameter.
    def each_internal_coupling
      internal_couplings.each { |src,ary| ary.each { |dst| yield(src,dst) }}
    end

    # Calls *block* once for each external output coupling (EOC) in
    # `#output_couplings`, passing that element as a parameter. Given *port* is
    # used to filter couplings having this port as a source.
    def each_output_coupling(port : Port)
      output_couplings[port].each { |dst| yield(port, dst) }
    end

    # Calls *block* once for each external output coupling (EOC) in
    # `#output_couplings`, passing that element as a parameter.
    def each_output_coupling
      output_couplings.each { |src,ary| ary.each { |dst| yield(src,dst) }}
    end

    # Calls *block* once for each coupling (EIC, IC, EOC), passing that element
    # as a parameter.
    def each_coupling
      each_input_coupling { |src, dst| yield(src, dst) }
      each_internal_coupling { |src, dst| yield(src, dst) }
      each_output_coupling { |src, dst| yield(src, dst) }
    end

    # Calls *block* once for each coupling (EIC, IC, EOC), passing that element
    # as a parameter. Given *port* is used to filter couplings having this
    # port as a source.
    def each_coupling(port : Port)
      each_input_coupling(port) { |src, dst| yield(src, dst) }
      each_internal_coupling(port) { |src, dst| yield(src, dst) }
      each_output_coupling(port) { |src, dst| yield(src, dst) }
    end

    # TODO
    # :nodoc:
    class CouplingIterator
      include Iterator({Port,Port})

      def initialize(@coupler : Coupler, @which : Symbol, @reverse : Bool = false)

      end

      def next

      end

      def rewind

      end
    end

    # TODO doc
    def each_input_coupling_reverse(port : Port)
      input_couplings.each do |src, ary|
        ary.each { |dst| yield(src, dst) if dst == port }
      end
    end

    # TODO doc
    def each_internal_coupling_reverse(port : Port)
      internal_couplings.each do |src, ary|
        ary.each { |dst| yield(src, dst) if dst == port }
      end
    end

    # TODO doc
    def each_output_coupling_reverse(port : Port)
      output_couplings.each do |src, ary|
        ary.each { |dst| yield(src, dst) if dst == port }
      end
    end

    # TODO doc
    def each_coupling_reverse(port : Port)
      each_input_coupling_reverse(port) { |src, dst| yield(src, dst) }
      each_internal_coupling_reverse(port) { |src, dst| yield(src, dst) }
      each_output_coupling_reverse(port) { |src, dst| yield(src, dst) }
    end

    # Adds a coupling to self between the two given ports.
    #
    # Depending on *p1* and *p2* hosts, the function will create an internal
    # coupling (IC), an external input coupling (EIC) or an external output
    # coupling (EOC).
    #
    # Raises a `FeedbackLoopError` if *p1* and *p2* hosts are the same child
    # when constructing an internal coupling. Direct feedback loops are not
    # allowed, i.e, no output port of a component may be connected to an input
    # port of the same component.
    # Raises an `InvalidPortModeError` if given ports are not of the expected IO
    # modes.
    # Raises an InvalidPortHostError if no coupling can be established from
    # given ports hosts.
    def attach(p1 : Port, to p2 : Port)
      a = p1.host
      b = p2.host

      if has_child?(a) && has_child?(b) # IC
        raise InvalidPortModeError.new unless p1.output? && p2.input?
        raise FeedbackLoopError.new("#{a} must be different than #{b}") if a.object_id == b.object_id
        internal_couplings[p1] << p2
      elsif a == self && has_child?(b)  # EIC
        raise InvalidPortModeError.new unless p1.input? && p2.input?
        input_couplings[p1] << p2
      elsif has_child?(a) && b == self  # EOC
        raise InvalidPortModeError.new unless p1.output? && p2.output?
        output_couplings[p1] << p2
      else
        raise InvalidPortHostError.new("Illegal coupling between #{p1} and #{p2}")
      end
    end

    # Adds a coupling to self. Establish a relation between the two given ports
    # that belongs respectively to *sender* and *receiver*.
    #
    # Note: If given port names *p1* and *p2* doesn't exist within their
    # host (respectively *sender* and *receiver*), they will be automatically
    # generated.
    def attach(p1 : Name, *, to p2 : Name, between sender : Coupleable, and receiver : Coupleable)
      ap1 = sender.find_or_create_output_port_if_necessary(p1)
      ap2 = receiver.find_or_create_input_port_if_necessary(p2)
      attach(ap1, to: ap2)
    end

    # Adds a coupling to self. Establish a relation between the two given ports
    # that belongs respectively to *sender* and *receiver*.
    #
    # Note: If given port names *p1* and *p2* doesn't exist within their
    # host (respectively *sender* and *receiver*), they will be automatically
    # generated.
    def attach(p1 : Name, *, to p2 : Name, between sender : Name, and receiver : Name)
      a = (sender == @name) ? self : self[sender]
      b = (receiver == @name) ? self : self[receiver]
      ap1 = a.find_or_create_output_port_if_necessary(p1)
      ap2 = b.find_or_create_input_port_if_necessary(p2)
      attach(ap1, to: ap2)
    end

    # Adds an external input coupling (EIC) to self. Establish a relation
    # between a self input port and a child input port.
    #
    # Note: If given port names *myport* and *iport* doesn't exist within their
    # host (respectively *self* and *child*), they will be automatically
    # generated.
    def attach_input(myport : Name, *, to iport : Name, of child : Coupleable)
      p1 = self.find_or_create_input_port_if_necessary(myport)
      p2 = child.find_or_create_input_port_if_necessary(iport)
      attach(p1, to: p2)
    end

    # Adds an external input coupling (EIC) to self. Establish a relation
    # between a self input port and a child input port.
    #
    # Note: If given port names *myport* and *iport* doesn't exist within their
    # host (respectively *self* and *child*), they will be automatically
    # generated.
    def attach_input(myport : Name, *, to iport : Name, of child : Name)
      receiver = self[receiver]
      p1 = self.find_or_create_input_port_if_necessary(myport)
      p2 = child.find_or_create_input_port_if_necessary(iport)
      attach(p1, to: p2)
    end

    # Adds an external output coupling (EOC) to self. Establish a relation
    # between an output port of one of self's children and one of self's
    # output ports.
    #
    # Note: If given port names *oport* and *myport* doesn't exist within their
    # host (respectively *child* and *self*), they will be automatically
    # generated.
    def attach_output(oport : Name, *, of child : Coupleable, to myport : Name)
      p1 = child.find_or_create_output_port_if_necessary(oport)
      p2 = self.find_or_create_output_port_if_necessary(myport)
      attach(p1, to: p2)
    end

    # Adds an external output coupling (EOC) to self. Establish a relation
    # between an output port of one of self's children and one of self's
    # output ports.
    #
    # Note: If given port names *oport* and *myport* doesn't exist within their
    # host (respectively *child* and *self*), they will be automatically
    # generated.
    def attach_output(oport : Name, *, of child : Name, to myport : Name)
      sender = self[child]
      p1 = sender.find_or_create_output_port_if_necessary(oport)
      p2 = self.find_or_create_output_port_if_necessary(myport)
      attach(p1, to: p2)
    end

    # Deletes a coupling from *self*. Returns `true` if successful.
    def detach(p1 : Port, from p2 : Port) : Bool
      a = p1.host
      b = p2.host

      if has_child?(a) && has_child?(b) # IC
        internal_couplings[p1].delete(p2)
      elsif a == self && has_child?(b)  # EIC
        input_couplings[p1].delete(p2)
      elsif has_child?(a) && b == self  # EOC
        output_couplings[p1].delete(p2)
      else
        false
      end
    end

    # Deletes a coupling from *self*. Returns `true` if successful.
    def detach(oport : Name, *, from iport : Name, between sender : Coupleable, and receiver : Coupleable) : Bool
      p1 = sender.output_port(oport)
      p2 = receiver.input_port(iport)
      detach(p1, from: p2)
    end

    # Deletes a coupling from *self*. Returns `true` if successful.
    def detach(oport : Name, *, from iport : Name, between sender : Name, and receiver : Name)
      a = (sender == @name) ? self : self[sender]
      b = (receiver == @name) ? self : self[receiver]
      p1 = a.output_port(oport)
      p2 = b.input_port(iport)
      detach(p1, from: p2)
    end

    # Deletes an external input coupling (EIC) from *self*. Returns `true` if
    # successful.
    def detach(myport : Name, *, from iport : Name, of receiver : Coupleable) : Bool
      p1 = self.input_port(myport)
      p2 = receiver.input_port(iport)
      detach(p1, from: p2)
    end

    # Deletes an external input coupling (EIC) from *self*. Returns `true` if
    # successful.
    def detach(myport : Name, *, from iport : Name, of receiver : Name) : Bool
      receiver = self[from]
      p1 = self.input_port(myport)
      p2 = receiver.input_port(iport)
      detach(p1, from: p2)
    end

    # Deletes an external output coupling (EOC) from *self*. Returns `true` if
    # successful.
    def detach(oport : Name, *, of child : Coupleable, from myport : Name) : Bool
      p1 = child.output_port(oport)
      p2 = self.output_port(myport)
      detach(p1, from: p2)
    end

    # Deletes an external output coupling (EOC) from *self*. Returns `true` if
    # successful.
    def detach(oport : Name, *, of child : Name, from myport : Name) : Bool
      sender = self[child]
      p1 = sender.output_port(oport)
      p2 = self.output_port(myport)
      detach(p1, from: p2)
    end
  end
end
