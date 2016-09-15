module Quartz

  # Base model class
  abstract class Model
    property name : Name, processor : Processor?

    # Returns a new model.
    def initialize(@name : Name); end

    def inspect(io)
      io << self.class << "(" << @name << ")"
    end

    def to_s(io)
      io << @name
      nil
    end
  end
end
