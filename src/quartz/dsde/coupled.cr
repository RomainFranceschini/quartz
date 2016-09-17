module Quartz
  module DSDE
    class CoupledModel < Quartz::CoupledModel

      getter executive

      def initialize(name : Name, @executive : Executive = Executive.new(:executive))
        super(name)
        @executive.network = self
        self << @executive # TODO remove from component list (but not from scheduler)
      end

      # TODO override these methods when executive is removed from component list
      # # Returns the children names
      # def children_names : Array(Name)
      #   children.keys
      # end
      #
      # # Find the component identified by the given *name*
      # #
      # # Raise `NoSuchChildError` error if *name* doesn't match any child
      # def [](name : Name) : Model
      #   raise NoSuchChildError.new unless children.has_key?(name)
      #   children[name]
      # end
      #
      # # Find the component identified by the given *name*
      # def []?(name : Name) : Model?
      #   children[name]?
      # end
      #
      # # Returns whether given *model* is a child of *self*
      # def has_child?(model : Model) : Bool
      #   children.has_key?(model.name)
      # end
      #
      # # Returns whether *self* has a child named like *name*
      # def has_child?(name : Name) : Bool
      #   children.has_key?(name)
      # end


    end
  end
end
