module DEVS

  # Base model class
  abstract class Model
  # TODO add a generic to represent DEVS::Type ?

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
