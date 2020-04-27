module Quartz
  # Base model class
  abstract class Model
    property name : Name
    property! processor : Processor?

    # Returns a new model.
    def initialize(@name : Name)
      after_initialize
    end

    def after_initialize
    end

    def inspect(io)
      io << self.class << "("
      @name.to_s(io)
      io << ")"
    end

    def to_s(io)
      io << @name
      nil
    end
  end
end
