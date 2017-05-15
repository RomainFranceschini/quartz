module Quartz
  module Visitor
    abstract def visit(model)

    def end_visit(model)
    end

    @[AlwaysInline]
    def visit_children?(model : Coupler)
      true
    end

    @[AlwaysInline]
    def visit_children?(model)
      false
    end

    def accept(model)
      model.accept(self)
    end
  end

  class Model
    def accept(visitor : Visitor)
      visitor.visit(self)
      if visitor.visit_children?(self)
        accept_children(visitor)
      end
      visitor.end_visit(self)
    end

    def accept_children(visitor)
    end
  end

  class CoupledModel
    def accept_children(visitor)
      children.each_value &.accept visitor
    end
  end

  class MultiComponent::Model
    def accept_children(visitor)
      components.each_value &.accept visitor
    end
  end
end
