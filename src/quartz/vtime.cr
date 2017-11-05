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
  abstract struct VTime
    # :nodoc:
    struct Infinity
    end

    # :nodoc:
    struct Zero
      include Comparable(Zero)
      include Comparable(Number)
      include Comparable(Infinity)

      def -(other)
        -other
      end

      def +(other)
        other
      end

      def *(other)
        self
      end

      def /(other)
        self
      end

      def -
        self
      end

      def <=>(other : Zero)
        0
      end

      def <=>(other : Infinity)
        other.positive? ? -1 : 1
      end

      def <=>(other)
        if 0 == other
          0
        elsif 0 < other
          -1
        else
          1
        end
      end
    end

    # :nodoc:
    struct Infinity
      include Comparable(Infinity)
      include Comparable(Number)
      include Comparable(Zero)

      def self.positive
        new(Sign::Positive)
      end

      def self.negative
        new(Sign::Negative)
      end

      enum Sign
        Positive
        Negative
      end

      @sign : Sign

      def initialize
        @sign = Sign::Positive
      end

      def initialize(@sign : Sign)
      end

      def negative? : Bool
        @sign.negative?
      end

      def positive? : Bool
        @sign.positive?
      end

      def -(other) : Infinity
        self
      end

      def +(other) : Infinity
        self
      end

      def *(other) : Infinity
        if other < 0
          -self
        else
          self
        end
      end

      def /(other) : Infinity
        if other < 0
          -self
        else
          self
        end
      end

      def - : Infinity
        if positive?
          Infinity.new(Sign::Negative)
        else
          Infinity.new(Sign::Positive)
        end
      end

      def <=>(other : Infinity)
        if positive?
          other.positive? ? 0 : 1
        else
          other.negative? ? 0 : -1
        end
      end

      def <=>(other : Float32)
        if positive?
          other == Float32::INFINITY ? 0 : 1
        else
          other == -Float32::INFINITY ? 0 : -1
        end
      end

      def <=>(other : Float64)
        if positive?
          other == Float64::INFINITY ? 0 : 1
        else
          other == -Float64::INFINITY ? 0 : -1
        end
      end

      def <=>(other)
        positive? ? 1 : -1
      end
    end
  end

  # TODO doc
  struct VirtualTime(T) < VTime
    include Comparable(VirtualTime)
    include Comparable(Number)

    # JSON.mapping(raw: T)

    def self.zero
      new(Zero.new)
    end

    def self.infinity
      new(Infinity.positive)
    end

    # getter raw : T | Infinity | Zero
    getter raw : T

    # def initialize(@raw : Zero)
    # end

    # def initialize(@raw : Infinity)
    # end

    def initialize(@raw : T)
      {% if T < Infinity || T == Zero %}
        # Support special infinity and zero values
      {% elsif !T.union? && T < Number::Primitive %}
        # Support primitive numbers
      {% elsif !T.union? && T < Comparable && T.methods.map(&.name.stringify).includes?("+") && T.methods.map(&.name.stringify).includes?("-") && T.methods.map(&.name.stringify).includes?("*") && T.methods.map(&.name.stringify).includes?("/") %}
        # Support comparable types supporting addition, substraction, division and multiplication
      {% else %}
        {{ raise "Can only create VirtualTime with comparable types supporting numeric operators, not #{T}." }}
      {% end %}
    end

    def infinity?
      @raw.is_a?(Infinity) || @raw == Float32::INFINITY || @raw == -Float32::INFINITY || @raw == Float64::INFINITY || @raw == -Float64::INFINITY
    end

    def zero?
      @raw.is_a?(Zero) || @raw == 0
    end

    # :nodoc:
    def hash
      @raw.hash
    end

    # :nodoc:
    def clone
      self
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
    def -(other : VirtualTime)
      VirtualTime.new(@raw - other.raw)
    end

    # Returns the result of subtracting the raw object and *other*.
    def -(other : T)
      VirtualTime.new(@raw - other)
    end

    # Returns the result of adding `self` and *other*'s raw object.
    def +(other : VirtualTime)
      VirtualTime.new(@raw + other.raw)
    end

    # Returns the result of adding the raw object and *other*.
    def +(other : T)
      VirtualTime.new(@raw + other)
    end

    # Returns the result of multiplying `self` and *other*'s raw object.
    def *(other : VirtualTime)
      VirtualTime.new(@raw * other.raw)
    end

    # Returns the result of multiplying the raw object and *other*.
    def *(other : T)
      VirtualTime.new(@raw * other)
    end

    # Returns the result of dividing `self` and *other*'s raw object.
    def /(other : VirtualTime)
      VirtualTime.new(@raw / other.raw)
    end

    # Returns the result of dividing the raw object and *other*.
    def /(other : T)
      VirtualTime.new(@raw / other)
    end

    def -
      VirtualTime.new(-@raw)
    end

    # # Returns the result of subtracting `self` and *other*'s raw object.
    # def -(other : VirtualTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw - other.raw)
    # end

    # # Returns the result of subtracting the raw object and *other*.
    # def -(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw - other)
    # end

    # # Returns the result of adding `self` and *other*'s raw object.
    # def +(other : VirtualTime(T)) : VirtualTime(T)
    #   VirtualTime(T).new(@raw + other.raw)
    # end

    # # Returns the result of adding the raw object and *other*.
    # def +(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw + other)
    # end

    # # Returns the result of multiplying `self` and *other*'s raw object.
    # def *(other : VirtualTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw * other.raw)
    # end

    # # Returns the result of multiplying the raw object and *other*.
    # def *(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw * other)
    # end

    # # Returns the result of dividing `self` and *other*'s raw object.
    # def /(other : VirtualTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw / other.raw)
    # end

    # # Returns the result of dividing the raw object and *other*.
    # def /(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw / other)
    # end

    # def - : VirtualTime(T)
    #   VirtualTime(T).new(-@raw)
    # end

    # --------------------------------------------

    # # Returns the result of subtracting `self` and *other*'s raw object.
    # def -(other : VTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw - other.raw)
    # end

    # # Returns the result of subtracting the raw object and *other*.
    # def -(other : T) # : VirtualTime(T)
    #   VirtualTime(T).new(@raw - other)
    # end

    # # Returns the result of adding `self` and *other*'s raw object.
    # def +(other : VTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw + other.raw)
    # end

    # # Returns the result of adding the raw object and *other*.
    # def +(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw + other)
    # end

    # # Returns the result of multiplying `self` and *other*'s raw object.
    # def *(other : VTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw * other.raw)
    # end

    # # Returns the result of multiplying the raw object and *other*.
    # def *(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw * other)
    # end

    # # Returns the result of dividing `self` and *other*'s raw object.
    # def /(other : VTime) : VirtualTime(T)
    #   VirtualTime(T).new(@raw / other.raw)
    # end

    # # Returns the result of dividing the raw object and *other*.
    # def /(other : T) : VirtualTime(T)
    #   VirtualTime(T).new(@raw / other)
    # end

    # def - : VirtualTime(T)
    #   VirtualTime(T).new(-@raw)
    # end

    def to_i
      @raw.to_i
    end

    def to_f
      @raw.to_f
    end
  end

  struct ::Number
    include Comparable(Quartz::VTime::Zero)
    include Comparable(Quartz::VTime::Infinity)

    def <=>(other : Quartz::VTime::Zero)
      self <=> 0
    end

    def <=>(other : Quartz::VTime::Infinity)
      -(other <=> self)
    end

    def +(other : Quartz::VTime::Zero)
      self
    end

    def -(other : Quartz::VTime::Zero)
      self
    end

    def *(other : Quartz::VTime::Zero)
      other
    end

    def /(other : Quartz::VTime::Zero)
      self / 0
    end

    def +(other : Quartz::VTime::Infinity)
      other
    end

    def -(other : Quartz::VTime::Infinity)
      -other
    end

    def *(other : Quartz::VTime::Infinity)
      if self < 0
        -other
      else
        other
      end
    end

    def /(other : Quartz::VTime::Infinity)
      Quartz::VirtualTime.new(self.class.zero)
    end
  end

  alias FloatVTime = VirtualTime(Float64)
  alias IntVTime = VirtualTime(Int64)
end
