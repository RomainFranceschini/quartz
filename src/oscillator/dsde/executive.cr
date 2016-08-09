module DEVS
  module DSDE
    # FIXME
    class Executive < DEVS::AtomicModel

      getter idle
      property network

      def initialize(name, @network : CoupledModel? = nil)
        super(name)
        {:add_model, :remove_model, :add_coupling, :remove_coupling, :add_input_port, :add_output_port, :remove_input_port, :remove_output_port}.each { |ip| add_input_port(ip) }
        add_output_port :result
      end

      def confluent_transition(bag)
        internal_transition
        external_transition(bag)
      end

      def external_transition(bag)
        bag.each do |port, payload|
          payload.each do |any|
            case port
            when input_port(:add_model)
              req = any.as_h
              # TODO find a way to dynamically instantiate a model
              new_model = req[:coupleable] as Coupleable
              add_model_to_network(new_model)
            when input_port(:add_input_port)
              req = any.as_h
              add_input_port_to_network(req[:model] as Symbol, req[:port] as Symbol)
            when input_port(:add_output_port)
              req = any.as_h
              add_output_port_to_network(req[:model] as Symbol, req[:port] as Symbol)
            when input_port(:add_coupling)
              req = any.as_h
              add_coupling_to_network(req[:src_port] as Symbol, to: req[:dst_port] as Symbol, between: req[:src] as Symbol, and: req[:dst] as Symbol)
            when input_port(:remove_coupling)
              req = any.as_h
              remove_coupling_from_network(req[:src_port] as Symbol, from: req[:dst_port] as Symbol, between: req[:src] as Symbol, and: req[:dst] as Symbol)
            when input_port(:remove_input_port)
              req = any.as_h
              remove_input_port_from_network(req[:model] as Symbol, req[:port] as Symbol)
            when input_port(:remove_output_port)
              req = any.as_h
              remove_output_port_from_network(req[:model] as Symbol, req[:port] as Symbol)
            when input_port(:remove_model)
              req = any.as_h
              remove_model_from_network(req[:model] as Symbol)
            end
          end
        end
        @sigma = 0
      end

      def internal_transition
        @sigma = INFINITY
      end

      def output
        # TODO requests validations
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
        @network.not_nil![model].add_input_port(port)
      end

      protected def add_output_port_to_network(model : Name, port : Name)
        @network.not_nil![model].add_output_port(port)
      end

      protected def remove_input_port_from_network(model : Name, port : Name)
        @network.not_nil![model].remove_input_port(port)
      end

      protected def remove_output_port_from_network(model : Name, port : Name)
        @network.not_nil![model].remove_output_port(port)
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
