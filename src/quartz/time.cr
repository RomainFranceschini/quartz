module Quartz
  # `VTime` is a wrapper for an underlying *virtual time* type.
  # The underlying type is an event time representation used to provide an
  # ordering of events consistent with causality.
  #
  # As a consequence, only number types, or dedicated types that provides the
  # comparison and numerical operators can be used with this `VTime` abstraction.
  #
  # `VTime` allows the modeler to choose the underlying virtual time
  # representation to simulate a model.
  struct VTime(T)
    include Comparable(self)

    getter raw : T

    def initialize(@raw : T)
      {% if !T.union? && T < Number::Primitive %}
        # Support primitive numbers
      {% elsif !T.union? && T < Comparable && T.methods.map(&.name.stringify).includes?("+") && T.methods.map(&.name.stringify).includes?("-") && T.methods.map(&.name.stringify).includes?("*") && T.methods.map(&.name.stringify).includes?("/") %}
        # Support comparable types supporting addition, substraction, division and multiplication
      {% else %}
        {{ raise "Can only create VTime with comparable types supporting numeric operators, not #{T}." }}
      {% end %}
    end

    def hash
      @raw.hash
    end

    # :nodoc:
    def inspect(io)
      @raw.inspect(io)
    end

    # :nodoc:
    def to_s(io)
      @raw.to_s(io)
    end

    # Returns true if both `self` and *other*'s raw object are equal.
    def ==(other : VTime) : Bool
      @raw == other.raw
    end

    # Returns true if the raw object is equal to *other*.
    def ==(other) : Bool
      @raw == other
    end

    # Returns true if `self` raw object is strictly less than *other*'s raw object.
    def <(other : VTime) : Bool
      @raw < other.raw
    end

    # Returns true if `self` raw object is strictly less than *other*.
    def <(other) : Bool
      @raw < other
    end

    # Returns true if `self` raw object is strictly greater than *other*'s raw object.
    def >(other : VTime) : Bool
      @raw > other.raw
    end

    # Returns true if `self` raw object is strictly greater than *other*.
    def >(other) : Bool
      @raw > other
    end

    # Returns true if `self` raw object is greater or equal to *other*'s raw object.
    def >=(other : VTime) : Bool
      @raw >= other.raw
    end

    # Returns true if `self` raw object is greater or equal to *other*.
    def >=(other) : Bool
      @raw >= other
    end

    # Returns true if `self` raw object is lesser or equal to *other*'s raw object.
    def <=(other : VTime) : Bool
      @raw <= other.raw
    end

    # Returns true if `self` raw object is lesser or equal to *other*.
    def <=(other) : Bool
      @raw <= other
    end

    # Compares `self` and *other*'s raw object.
    def <=>(other : VTime) : Int32
      @raw <=> other.raw
    end

    # Compares the raw object to *other*.
    def <=>(other) : Int32
      @raw <=> other
    end

    # Returns the result of subtracting `self` and *other*'s raw object.
    def -(other : VTime(T)) : VTime(T)
      VTime.new(@raw - other.raw)
    end

    # Returns the result of subtracting the raw object and *other*.
    def -(other : T) : VTime(T)
      VTime.new(@raw - other)
    end

    # Returns the result of adding `self` and *other*'s raw object.
    def +(other : VTime(T)) : VTime(T)
      VTime.new(@raw + other.raw)
    end

    # Returns the result of adding the raw object and *other*.
    def +(other : T) : VTime(T)
      VTime.new(@raw + other)
    end

    # Returns the result of multiplying `self` and *other*'s raw object.
    def *(other : VTime(T)) : VTime(T)
      VTime.new(@raw * other.raw)
    end

    # Returns the result of multiplying the raw object and *other*.
    def *(other : T) : VTime(T)
      VTime.new(@raw * other)
    end

    # Returns the result of dividing `self` and *other*'s raw object.
    def /(other : VTime(T)) : VTime(T)
      VTime.new(@raw / other.raw)
    end

    # Returns the result of dividing the raw object and *other*.
    def /(other : T) : VTime(T)
      VTime.new(@raw / other)
    end

    def - : VTime(T)
      VTime.new(-@raw)
    end
  end
end
