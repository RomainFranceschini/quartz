module DEVS

  module ModelType; end

  # Base model class
  abstract class Model
    include ModelType

    property :name, :processor

    @processor : ProcessorType?

    # Returns a new model.
    def initialize(@name : String | Symbol); end

    def inspect
      "<#{self.class}: name=#{@name}>"
    end

    def to_s
      name.to_s
    end
  end
end
