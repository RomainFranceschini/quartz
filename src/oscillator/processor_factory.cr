module DEVS

  # TODO fixme when introducing cdevs
  abstract class ProcessorFactory

    class ProcessorAllocationError < Exception; end

    def self.processor_for(model : Model, scheduler, namespace, root = false)
      if model.is_a?(DSDE::CoupledModel)
        if root
          PDEVS::DSDE::RootCoordinator.new(model, namespace, scheduler)
        else
          PDEVS::DSDE::Coordinator.new(model, namespace, scheduler)
        end
      elsif model.is_a?(CoupledModel)
        if root
          PDEVS::RootCoordinator.new(model, namespace, scheduler)
        else
          PDEVS::Coordinator.new(model, namespace, scheduler)
        end
      #elsif model.is_a?(MultiComponent::Model)
      #  PDEVS::MultiComponent::Simulator.new(model, scheduler)
      elsif model.is_a?(AtomicModel)
        PDEVS::Simulator.new(model)
      else
        raise ProcessorAllocationError.new("processor can't be created for model #{model.name}")
      end
    end

  end
end
