module Quartz
  class ProcessorAllocator
    include Visitor

    class ProcessorAllocationError < Exception; end

    @simulation : Simulation
    @stack : Array(Coordinator)
    @root_model : CoupledModel?

    @root_coordinator : Coordinator?

    def simulable : Simulable
      @root_coordinator.as(Simulable)
    end

    def initialize(@simulation, @root_model)
      @stack = Array(Coordinator).new
    end

    def initialize(@simulation, parent_processor : Coordinator)
      @stack = Array(Coordinator).new
      @stack.push parent_processor
    end

    def visit(model : DSDE::CoupledModel)
      processor = if model == @root_model
                    @root_coordinator = DSDE::RootCoordinator.new(model, @simulation)
                  else
                    DSDE::DynamicCoordinator.new(model, @simulation)
                  end
      if parent = @stack.last?
        parent << processor
      end
      @stack.push processor
    end

    def visit(model : CoupledModel)
      processor = if model == @root_model
                    @root_coordinator = RootCoordinator.new(model, @simulation)
                  else
                    Coordinator.new(model, @simulation)
                  end
      if parent = @stack.last?
        parent << processor
      end
      @stack.push processor
    end

    def end_visit(model : CoupledModel)
      @stack.pop
    end

    def visit(model : AtomicModel)
      @stack.last << Simulator.new(model, @simulation)
    end

    def visit(model : MultiComponent::Model)
      @stack.last << MultiComponent::Simulator.new(model, @simulation)
    end

    def visit(model : DTSS::AtomicModel)
      @stack.last << DTSS::Simulator.new(model, @simulation)
    end

    def visit(model)
      raise ProcessorAllocationError.new("No processor able to simulate \"#{model.name}\" model.")
    end
  end
end
