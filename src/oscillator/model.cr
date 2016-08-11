module DEVS

  # Base model class
  abstract class Model
  # TODO add a generic to represent DEVS::Type ?

    property :name, :processor

    @processor : ProcessorType?

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
