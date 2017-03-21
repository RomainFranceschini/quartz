module Quartz
  module ProcessorFactory
    class ProcessorAllocationError < Exception; end

    def self.processor_for(model : Model, sim : Simulation, root = false)
      if model.is_a?(DSDE::CoupledModel)
        if root
          RootCoordinator.new(model, sim)
        else
          DSDE::Coordinator.new(model, sim)
        end
      elsif model.is_a?(CoupledModel)
        if root
          RootCoordinator.new(model, sim)
        else
          Coordinator.new(model, sim)
        end
      elsif model.is_a?(MultiComponent::Model)
        MultiComponent::Simulator.new(model, sim)
      elsif model.is_a?(AtomicModel)
        Simulator.new(model, sim)
      else
        raise ProcessorAllocationError.new("No processor able to simulate \"#{model.name}\" model.")
      end
    end
  end
end
