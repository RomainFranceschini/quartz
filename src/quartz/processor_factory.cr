module Quartz
  abstract class ProcessorFactory
    class ProcessorAllocationError < Exception; end

    def self.processor_for(model : Model, scheduler, root = false)
      if model.is_a?(DSDE::CoupledModel)
        if root
          DSDE::RootCoordinator.new(model, scheduler)
        else
          DSDE::Coordinator.new(model, scheduler)
        end
      elsif model.is_a?(CoupledModel)
        if root
          RootCoordinator.new(model, scheduler)
        else
          Coordinator.new(model, scheduler)
        end
      elsif model.is_a?(MultiComponent::Model)
        MultiComponent::Simulator.new(model, scheduler)
      elsif model.is_a?(AtomicModel)
        Simulator.new(model)
      else
        raise ProcessorAllocationError.new("No processor able to simulate \"#{model.name}\" model.")
      end
    end
  end
end
