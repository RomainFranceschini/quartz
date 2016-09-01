module Quartz
  module MultiComponent
    class Model < Quartz::Model
      #include Observable(PortObserver)
      #include Observable(TransitionObserver)
      include Coupleable

      getter components = Hash(Name, Component).new

      def <<(component)
        @components[component.name] = component
      end

      # The *Select* function as defined is the classic DEVS formalism.
      # Select one {Model} among all. By default returns the first. Override
      # if a different behavior is desired.
      def select(imminent_children)
        imminent_children.first
      end
    end
  end
end
