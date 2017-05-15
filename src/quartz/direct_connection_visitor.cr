module Quartz
  class DirectConnectionVisitor
    include Visitor

    def initialize(@root : CoupledModel)
      @children = Array(Model).new
      @new_internal_couplings = Hash(OutputPort, Array(InputPort)).new { |h, k|
        h[k] = [] of InputPort
      }
    end

    def visit(model : CoupledModel)
      return if model == @root

      # get internal couplings between atomics that we can reuse as-is in the
      # root coupled model.
      model.each_internal_coupling do |src, dst|
        if src.host.is_a?(AtomicModel) && dst.host.is_a?(AtomicModel)
          @new_internal_couplings[src] << dst
        end
      end
    end

    def end_visit(model : CoupledModel)
      if model == @root
        iterator = model.each_child.each { |c| model.remove_child(c) }
        @children.each { |c| model << c }

        model.find_direct_couplings do |src, dst|
          @new_internal_couplings[src] << dst
        end

        internal_couplings = model.internal_couplings.clear

        @new_internal_couplings.each do |src, ary|
          src.peers_ports.clear
          src.upward_ports.clear

          ary.each do |dst|
            src.peers_ports << dst
            dst.downward_ports.clear
          end

          internal_couplings << src
        end
      end
    end

    def visit(model)
      @children << model
    end
  end
end
