module Quartz
  # This mixin provides coupled models with several components and
  # coupling methods.
  module Coupler
    @children : Hash(Name, Model)?
    @internal_couplings : Array(OutputPort)?
    @output_couplings : Array(OutputPort)?
    @input_couplings : Array(InputPort)?
    @transducers : Hash({Port, Port}, Proc(Enumerable(Any), Enumerable(Any)))?

    # :nodoc:
    protected def children : Hash(Name, Model)
      @children ||= Hash(Name, Model).new
    end

    # :nodoc:
    protected def internal_couplings : Array(OutputPort)
      @internal_couplings ||= Array(OutputPort).new
    end

    # :nodoc:
    protected def output_couplings : Array(OutputPort)
      @output_couplings ||= Array(OutputPort).new
    end

    # :nodoc:
    protected def input_couplings : Array(InputPort)
      @input_couplings ||= Array(InputPort).new
    end

    # :nodoc:
    protected def transducers : Hash({Port, Port}, Proc(Enumerable(Any), Enumerable(Any)))
      @transducers ||= Hash({Port, Port}, Proc(Enumerable(Any), Enumerable(Any))).new
    end

    # Returns all internal couplings attached to the given output *port*.
    def internal_couplings(port : OutputPort) : Array(InputPort)
      port.siblings_ports
    end

    # Returns all external output couplings attached to the given output *port*.
    def output_couplings(port : OutputPort) : Array(OutputPort)
      port.upward_ports
    end

    # Returns all external input couplings attached to the given input *port*.
    def input_couplings(port : InputPort) : Array(InputPort)
      port.downward_ports
    end

    # Append the given *model* to childrens
    def <<(model : Model)
      children[model.name] = model
      self
    end

    # Alias for `#<<`.
    def add_child(child)
      self << child
    end

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
    def has_child?(model : Coupleable) : Bool
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

    # Returns the number of children in `self`.
    def children_size
      children.size
    end

    # Whether the given coupling has an associated transducer.
    def has_transducer_for?(src : Port, dst : Port) : Bool
      @transducers.try &.has_key?({src, dst}) || false
    end

    # Returns the transducer associated with the given coupling.
    def transducer_for(src : Port, dst : Port)
      transducers[{src, dst}]
    end

    # Calls *block* once for each external input coupling (EIC) in
    # `#input_couplings`, passing that element as a parameter. Given *port* is
    # used to filter couplings having this port as a source.
    # TODO check if port in input_couplings ?
    def each_input_coupling(port : InputPort)
      port.downward_ports.each { |dst| yield(port, dst) }
    end

    # Calls *block* once for each external input coupling (EIC) in
    # `#input_couplings`, passing that element as a parameter.
    def each_input_coupling
      input_couplings.each { |src| src.downward_ports.each { |dst| yield(src, dst) } }
    end

    # Calls *block* once for each internal coupling (IC) in
    # `#internal_couplings`, passing that element as a parameter. Given *port*
    # is used to filter couplings having this port as a source.
    def each_internal_coupling(port : OutputPort)
      port.siblings_ports.each { |dst| yield(port, dst) }
    end

    # Calls *block* once for each internal coupling (IC) in
    # `#internal_couplings`, passing that element as a parameter.
    def each_internal_coupling
      internal_couplings.each { |src| src.siblings_ports.each { |dst| yield(src, dst) } }
    end

    # Calls *block* once for each external output coupling (EOC) in
    # `#output_couplings`, passing that element as a parameter. Given *port* is
    # used to filter couplings having this port as a source.
    def each_output_coupling(port : OutputPort)
      port.upward_ports.each { |dst| yield(port, dst) }
    end

    # Calls *block* once for each external output coupling (EOC) in
    # `#output_couplings`, passing that element as a parameter.
    def each_output_coupling
      output_couplings.each { |src| src.upward_ports.each { |dst| yield(src, dst) } }
    end

    # Calls *block* once for each coupling (EIC, IC, EOC), passing that element
    # as a parameter.
    def each_coupling
      each_input_coupling { |src, dst| yield(src, dst) }
      each_internal_coupling { |src, dst| yield(src, dst) }
      each_output_coupling { |src, dst| yield(src, dst) }
    end

    # Calls *block* once for each coupling, passing that element as a parameter.
    # Given input *port* is used to filter external input couplings (EIC) having
    # this port as a source.
    def each_coupling(port : InputPort)
      each_input_coupling(port) { |src, dst| yield(src, dst) }
    end

    # Calls *block* once for each coupling, passing that element as a parameter.
    # Given output *port* is used to filter internal couplings and external
    # output couplings (IC, EOC) having this port as a source.
    def each_coupling(port : OutputPort)
      each_internal_coupling(port) { |src, dst| yield(src, dst) }
      each_output_coupling(port) { |src, dst| yield(src, dst) }
    end

    # TODO
    # :nodoc:
    class CouplingIterator
      include Iterator({Port, Port})

      def initialize(@coupler : Coupler, @which : Symbol, @reverse : Bool = false)
      end

      def next
      end

      def rewind
      end
    end

    # TODO doc
    def each_input_coupling_reverse(port : InputPort)
      input_couplings.each do |src|
        src.downward_ports.each { |dst| yield(src, dst) if dst == port }
      end
    end

    # TODO doc
    def each_internal_coupling_reverse(port : InputPort)
      internal_couplings.each do |src|
        src.siblings_ports.each { |dst| yield(src, dst) if dst == port }
      end
    end

    # TODO doc
    def each_output_coupling_reverse(port : OutputPort)
      output_couplings.each do |src|
        src.upward_ports.each { |dst| yield(src, dst) if dst == port }
      end
    end

    # TODO doc
    def each_coupling_reverse(port : InputPort)
      each_input_coupling_reverse(port) { |src, dst| yield(src, dst) }
      each_internal_coupling_reverse(port) { |src, dst| yield(src, dst) }
    end

    def each_coupling_reverse(port : OutputPort)
      each_output_coupling_reverse(port) { |src, dst| yield(src, dst) }
    end

    # Adds an external input coupling (EIC) to self between the two given input
    # ports.
    #
    # Raises an `InvalidPortHostError` if no coupling can be established from
    # given ports hosts.
    def attach(p1 : InputPort, to p2 : InputPort)
      a = p1.host
      b = p2.host

      if a == self && has_child?(b) # EIC
        input_couplings << p1 if p1.downward_ports.empty?
        p1.downward_ports << p2
      else
        raise InvalidPortHostError.new("Illegal coupling between #{p1} and #{p2}")
      end
    end

    # ditto
    def attach(p1 : InputPort, to p2 : InputPort, &block : Enumerable(Any) -> Enumerable(Any))
      attach(p1, p2)
      transducers[{p1, p2}] = block
    end

    # Adds an internal coupling (IC) to self between the two given ports.
    #
    # Raises a `FeedbackLoopError` if *p1* and *p2* hosts are the same child
    # when constructing the internal coupling. Direct feedback loops are not
    # allowed, i.e, no output port of a component may be connected to an input
    # port of the same component.
    # Raises an `InvalidPortHostError` if no coupling can be established from
    # given ports hosts.
    def attach(p1 : OutputPort, to p2 : InputPort)
      a = p1.host
      b = p2.host

      if has_child?(a) && has_child?(b) # IC
        raise FeedbackLoopError.new("#{a} must be different than #{b}") if a.object_id == b.object_id
        internal_couplings << p1 if p1.siblings_ports.empty?
        p1.siblings_ports << p2
      else
        raise InvalidPortHostError.new("Illegal coupling between #{p1} and #{p2}")
      end
    end

    # ditto
    def attach(p1 : OutputPort, to p2 : InputPort, &block : Enumerable(Any) -> Enumerable(Any))
      attach(p1, p2)
      transducers[{p1, p2}] = block
    end

    # Adds an external output coupling (EOC) to self between the two given
    # output ports.
    #
    # Raises an `InvalidPortHostError` if no coupling can be established from
    # given ports hosts.
    def attach(p1 : OutputPort, to p2 : OutputPort)
      a = p1.host
      b = p2.host

      if has_child?(a) && b == self # EOC
        output_couplings << p1 if p1.upward_ports.empty?
        p1.upward_ports << p2
      else
        raise InvalidPortHostError.new("Illegal coupling between #{p1} and #{p2}")
      end
    end

    # ditto
    def attach(p1 : OutputPort, to p2 : OutputPort, &block : Enumerable(Any) -> Enumerable(Any))
      attach(p1, p2)
      transducers[{p1, p2}] = block
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

    # ditto
    def attach(p1 : Name, *, to p2 : Name, between sender : Coupleable, and receiver : Coupleable, &block : Enumerable(Any) -> Enumerable(Any))
      ap1 = sender.find_or_create_output_port_if_necessary(p1)
      ap2 = receiver.find_or_create_input_port_if_necessary(p2)
      attach(ap1, to: ap2, &block)
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
      ap1 = a.as(Coupleable).find_or_create_output_port_if_necessary(p1)
      ap2 = b.as(Coupleable).find_or_create_input_port_if_necessary(p2)
      attach(ap1, to: ap2)
    end

    # ditto
    def attach(p1 : Name, *, to p2 : Name, between sender : Name, and receiver : Name, &block : Enumerable(Any) -> Enumerable(Any))
      a = (sender == @name) ? self : self[sender]
      b = (receiver == @name) ? self : self[receiver]
      ap1 = a.as(Coupleable).find_or_create_output_port_if_necessary(p1)
      ap2 = b.as(Coupleable).find_or_create_input_port_if_necessary(p2)
      attach(ap1, to: ap2, &block)
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

    # ditto
    def attach_input(myport : Name, *, to iport : Name, of child : Coupleable, &block : Enumerable(Any) -> Enumerable(Any))
      p1 = self.find_or_create_input_port_if_necessary(myport)
      p2 = child.find_or_create_input_port_if_necessary(iport)
      attach(p1, to: p2, &block)
    end

    # Adds an external input coupling (EIC) to self. Establish a relation
    # between a self input port and a child input port.
    #
    # Note: If given port names *myport* and *iport* doesn't exist within their
    # host (respectively *self* and *child*), they will be automatically
    # generated.
    def attach_input(myport : Name, *, to iport : Name, of child : Name)
      receiver = self[child].as(Coupleable)
      p1 = self.find_or_create_input_port_if_necessary(myport)
      p2 = receiver.find_or_create_input_port_if_necessary(iport)
      attach(p1, to: p2)
    end

    # ditto
    def attach_input(myport : Name, *, to iport : Name, of child : Name, &block : Enumerable(Any) -> Enumerable(Any))
      receiver = self[child].as(Coupleable)
      p1 = self.find_or_create_input_port_if_necessary(myport)
      p2 = receiver.find_or_create_input_port_if_necessary(iport)
      attach(p1, to: p2, &block)
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

    # ditto
    def attach_output(oport : Name, *, of child : Coupleable, to myport : Name, &block : Enumerable(Any) -> Enumerable(Any))
      p1 = child.find_or_create_output_port_if_necessary(oport)
      p2 = self.find_or_create_output_port_if_necessary(myport)
      attach(p1, to: p2, &block)
    end

    # Adds an external output coupling (EOC) to self. Establish a relation
    # between an output port of one of self's children and one of self's
    # output ports.
    #
    # Note: If given port names *oport* and *myport* doesn't exist within their
    # host (respectively *child* and *self*), they will be automatically
    # generated.
    def attach_output(oport : Name, *, of child : Name, to myport : Name)
      sender = self[child].as(Coupleable)
      p1 = sender.find_or_create_output_port_if_necessary(oport)
      p2 = self.find_or_create_output_port_if_necessary(myport)
      attach(p1, to: p2)
    end

    # ditto
    def attach_output(oport : Name, *, of child : Name, to myport : Name, &block : Enumerable(Any) -> Enumerable(Any))
      sender = self[child].as(Coupleable)
      p1 = sender.find_or_create_output_port_if_necessary(oport)
      p2 = self.find_or_create_output_port_if_necessary(myport)
      attach(p1, to: p2, &block)
    end

    # Deletes a external input coupling (EOC) from *self*.
    #
    # Returns `true` if successful.
    def detach(p1 : InputPort, from p2 : InputPort) : Bool
      a = p1.host
      b = p2.host

      if a == self && has_child?(b) # EIC
        if p1.downward_ports.delete(p2) != nil
          if p1.downward_ports.empty?
            input_couplings.delete(p1)
          end
          @transducers.try &.delete({p1, p2})
          return true
        end
      end

      false
    end

    # Deletes an internal coupling (IC) from *self*.
    #
    # Returns `true` if successful.
    def detach(p1 : OutputPort, from p2 : InputPort) : Bool
      a = p1.host
      b = p2.host

      if has_child?(a) && has_child?(b) # IC
        if p1.siblings_ports.delete(p2) != nil
          if p1.siblings_ports.empty?
            internal_couplings.delete(p1)
          end
          @transducers.try &.delete({p1, p2})
          return true
        end
      end

      false
    end

    # Deletes an external output coupling (EOC) from *self*.
    #
    # Returns `true` if successful.
    def detach(p1 : OutputPort, from p2 : OutputPort) : Bool
      a = p1.host
      b = p2.host

      if has_child?(a) && b == self # EOC
        if p1.upward_ports.delete(p2) != nil
          if p1.upward_ports.empty?
            output_couplings.delete(p1)
          end
          @transducers.try &.delete({p1, p2})
          return true
        end
      end

      false
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
      p1 = a.as(Coupleable).output_port(oport)
      p2 = b.as(Coupleable).input_port(iport)
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

    # Finds and yields direct connections in the coupling graph of *self*.
    def find_direct_couplings(&block : OutputPort, InputPort, Array(Proc(Enumerable(Any), Enumerable(Any))) ->)
      couplings = [] of {Port, Port}
      coupling_set = Hash({Port, Port}, Array(Proc(Enumerable(Any), Enumerable(Any)))).new { |h, k|
        h[k] = Array(Proc(Enumerable(Any), Enumerable(Any))).new
      }

      self.each_internal_coupling do |s, d|
        couplings << {s, d}
        if self.has_transducer_for?(s, d)
          coupling_set[{s, d}] << self.transducer_for(s, d)
        end
      end

      mappers = Array(Proc(Enumerable(Any), Enumerable(Any))).new
      while !couplings.empty?
        osrc, odst = couplings.pop

        if !osrc.host.is_a?(Coupler) && !odst.host.is_a?(Coupler)
          yield(osrc.as(OutputPort), odst.as(InputPort), coupling_set[{osrc, odst}]) # found direct coupling
        elsif osrc.host.is_a?(Coupler)                                               # eic
          route = [{osrc, odst}]
          while !route.empty?
            rsrc, _ = route.pop
            coupler = rsrc.host.as(Coupler)
            coupler.each_output_coupling_reverse(rsrc.as(OutputPort)) do |src, dst|
              if coupler.has_transducer_for?(src, dst)
                mappers << coupler.transducer_for(src, dst)
              end
              if src.host.is_a?(Coupler)
                route.push({src, dst})
              else
                unless coupling_set.has_key?({src, odst})
                  couplings.push({src, odst})
                  coupling_set[{src, odst}] = mappers.reverse!.concat(coupling_set[{osrc, odst}])
                end
              end
            end
          end
        elsif odst.host.is_a?(Coupler) # eoc
          route = [{osrc, odst}]
          while !route.empty?
            _, rdst = route.pop
            coupler = rdst.host.as(Coupler)
            coupler.each_input_coupling(rdst.as(InputPort)) do |src, dst|
              if coupler.has_transducer_for?(src, dst)
                mappers << coupler.transducer_for(src, dst)
              end
              if dst.host.is_a?(Coupler)
                route.push({src, dst})
              else
                unless coupling_set.has_key?({osrc, dst})
                  couplings.push({osrc, dst})
                  coupling_set[{osrc, dst}] = coupling_set[{osrc, odst}].dup.concat(mappers)
                end
              end
            end
          end
        end

        mappers.clear
      end
    end
  end
end
