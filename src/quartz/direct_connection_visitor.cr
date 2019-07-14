module Quartz
  class DirectConnectionVisitor
    include Visitor

    def initialize(@root : CoupledModel)
      @children = Array(Model).new
      @new_internal_couplings = Hash(OutputPort, Array(InputPort)).new { |h, k|
        h[k] = [] of InputPort
      }
      @transducers = Hash({Port, Port}, Proc(Enumerable(Any), Enumerable(Any))).new
    end

    def visit(model : CoupledModel)
      return if model == @root

      # get internal couplings between atomics that we can reuse as-is in the
      # root coupled model.
      model.each_internal_coupling do |src, dst|
        if src.host.is_a?(AtomicModel) && dst.host.is_a?(AtomicModel)
          @new_internal_couplings[src] << dst
          if model.has_transducer_for?(src, dst)
            @transducers[{src, dst}] = model.transducer_for(src, dst)
          end
        end
      end
    end

    def end_visit(model : CoupledModel)
      if model == @root
        iterator = model.each_child.each { |c| model.remove_child(c) }
        @children.each { |c| model << c }

        model.find_direct_couplings do |src, dst, mappers|
          @new_internal_couplings[src] << dst

          if mappers.size == 1
            @transducers[{src, dst}] = mappers.first
          elsif mappers.size > 1
            @transducers[{src, dst}] = ->(values : Enumerable(Any)) {
              mappers.each { |mapper|
                values = mapper.call(values)
              }
              values
            }
          end
        end

        internal_couplings = model.internal_couplings.clear
        transducers = model.transducers.clear

        @new_internal_couplings.each do |src, ary|
          src.siblings_ports.clear
          src.upward_ports.clear

          ary.each do |dst|
            src.siblings_ports << dst
            dst.downward_ports.clear

            if @transducers.has_key?({src, dst})
              transducers[{src, dst}] = @transducers[{src, dst}]
            end
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
