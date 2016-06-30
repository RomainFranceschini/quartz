module DEVS

  # compiler problem in 0.16.0 with generics (see #2558)
  module ProcessorType; end

  abstract class Processor#(T)
    include ProcessorType

    #include Logging
    #include Comparable(self)
    getter :model, :time_next, :time_last
    property :parent

    # @!attribute [rw] parent
    #   @return [Coordinator] Returns the parent {Coordinator}

    # @!attribute [r] model
    #   @return [Model] Returns the model associated with <tt>self</tt>

    # @!attribute [r] time_next
    #   @return [Numeric] Returns the next simulation time at which the
    #     associated {Model} should be activated

    # @!attribute [r] time_last
    #   @return [Numeric] Returns the last simulation time at which the
    #     associated {Model} was activated

    @time_next : SimulationTime
    @time_last : SimulationTime

    @parent : Coordinator?

    def initialize(@model : Model)
      @time_next = 0
      @time_last = 0
      @model.processor = self
    end

    # The comparison operator. Compares two processors given their #time_next
    #
    # @param other [Processor]
    # @return [Integer]
    # def <=>(other)
    #   other.time_next <=> @time_next
    # end

    def inspect
      "<#{self.class}: tn=#{@time_next}, tl=#{@time_last}>"
    end
  end
end
