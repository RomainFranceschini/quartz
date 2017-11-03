module Quartz
  module DSDE
    # FIXME
    class Executive < Quartz::AtomicModel
      getter idle
      property network

      output :ack
      input :add_model, :remove_model, :add_coupling, :remove_coupling,
        :add_input_port, :add_output_port, :remove_input_port,
        :remove_output_port

      def initialize(name, @network : CoupledModel? = nil)
        super(name)
      end

      def confluent_transition(bag)
        internal_transition
        external_transition(bag)
      end

      def external_transition(bag)
        bag[input_port(:add_model)].flatten.each do |any|
          req = any.as_h
          # TODO find a way to dynamically instantiate a model
          new_model = req[:coupleable].raw.as(Coupleable)
          add_model_to_network(new_model)
        end

        bag[input_port(:add_input_port)].flatten.each do |any|
          req = any.as_h
          add_input_port_to_network(req[:model].raw.as(Name), req[:port].raw.as(Name))
        end

        bag[input_port(:add_output_port)].flatten.each do |any|
          req = any.as_h
          add_output_port_to_network(req[:model].raw.as(Name), req[:port].raw.as(Name))
        end

        bag[input_port(:add_coupling)].flatten.each do |any|
          req = any.as_h
          add_coupling_to_network(req[:src_port].raw.as(Name), to: req[:dst_port].raw.as(Name), between: req[:src].raw.as(Name), and: req[:dst].raw.as(Name))
        end

        bag[input_port(:remove_coupling)].flatten.each do |any|
          req = any.as_h
          remove_coupling_from_network(req[:src_port].raw.as(Name), from: req[:dst_port].raw.as(Name), between: req[:src].raw.as(Name), and: req[:dst].raw.as(Name))
        end

        bag[input_port(:remove_input_port)].flatten.each do |any|
          req = any.as_h
          remove_input_port_from_network(req[:model].raw.as(Name), req[:port].raw.as(Name))
        end

        bag[input_port(:remove_output_port)].flatten.each do |any|
          req = any.as_h
          remove_output_port_from_network(req[:model].raw.as(Name), req[:port].raw.as(Name))
        end

        bag[input_port(:remove_model)].flatten.each do |any|
          req = any.as_h
          remove_model_from_network(req[:model].raw.as(Name))
        end

        @sigma = 0
      end

      def internal_transition
        @sigma = INFINITY
      end

      def output
        # NOTE: Always send ACK since at this point we know graph changes
        # occured as we don't catch errors.
        # TODO: Propose alternative policy where we catch errors and send NAK ?

        post "\u{6}", :ack
      end

      # TODO ports and couplings checks
      private def remove_model_from_network(model : Name)
        # TODO save transition stats ?
        @network.not_nil!.remove_child(@network.not_nil![model])
      end

      protected def add_model_to_network(model : Coupleable)
        @network.not_nil! << model
      end

      protected def add_input_port_to_network(model : Name, port : Name)
        @network.not_nil![model].as(Coupleable).add_input_port(port)
      end

      protected def add_output_port_to_network(model : Name, port : Name)
        @network.not_nil![model].as(Coupleable).add_output_port(port)
      end

      protected def remove_input_port_from_network(model : Name, port : Name)
        @network.not_nil![model].as(Coupleable).remove_input_port(port)
      end

      protected def remove_output_port_from_network(model : Name, port : Name)
        @network.not_nil![model].as(Coupleable).remove_output_port(port)
      end

      protected def add_coupling_to_network(p1 : Name, *, to p2 : Name, between sender : Name, and receiver : Name)
        @network.not_nil!.attach(p1, to: p2, between: sender, and: receiver)
      end

      protected def remove_coupling_from_network(p1 : Name, *, from p2 : Name, between sender : Name, and receiver : Name)
        @network.not_nil!.detach(p1, from: p2, between: sender, and: receiver)
      end
    end
  end
end
