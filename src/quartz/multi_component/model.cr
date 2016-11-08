module Quartz
  module MultiComponent
    class Model < Quartz::Model
      include Observable
      include Coupleable

      getter components = Hash(Name, Component).new

      def <<(component)
        @components[component.name] = component
      end
    end
  end
end
