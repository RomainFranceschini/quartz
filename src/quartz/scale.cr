module Quartz
  # `Scale` is an approximation of the degree to which `Duration`s must
  # be altered to have an appreciable effect on the implications of a model or
  # the results of a simulation.
  struct Scale
    include Comparable(Scale)
    include Comparable(Number)

    # The base constant ß is a factor that separates one allowable time unit from
    # the next.
    FACTOR = 1000_i64

    YOCTO = new(-8)
    ZEPTO = new(-7)
    ATTO  = new(-6)
    FEMTO = new(-5)
    PICO  = new(-4)
    NANO  = new(-3)
    MICRO = new(-2)
    MILLI = new(-1)
    BASE  = new(0)
    KILO  = new(1)
    MEGA  = new(2)
    GIGA  = new(3)
    TERA  = new(4)
    PETA  = new(5)
    EXA   = new(6)
    ZETTA = new(7)
    YOTTA = new(8)

    # The level of accuracy.
    getter level : Int8

    def initialize
      @level = 0u8
    end

    def initialize(scale : Int)
      @level = scale.to_i8
    end

    def_clone

    # Returns the result of adding `self` and *other*.
    def +(other : Int) : Scale
      Scale.new(@level + other)
    end

    # Returns the result of subtracting `self` and *other*.
    def -(other : Int) : Scale
      Scale.new(@level - other)
    end

    # Returns an integer which represent the distance between two given scales.
    def -(other : Scale) : Int32
      (@level + -other.level).abs.to_i32
    end

    # Returns the result of dividing `self` and *other*.
    def /(other : Scale) : Float64
      FACTOR.to_f ** (@level.to_i - other.level)
    end

    # Negates self.
    def - : Scale
      Scale.new(-@level)
    end

    def <=>(other : Scale) : Int32
      @level <=> other.level
    end

    def <=>(other : Number) : Int32
      @level <=> other
    end

    def to_f32
      FACTOR.to_f32 ** @level
    end

    def to_f64
      FACTOR.to_f64 ** @level
    end

    def to_f
      to_f64
    end
  end
end

# :nodoc:
struct ::Number
  def +(other : Quartz::Scale)
    Quartz::Scale.new(self.to_i + other.level)
  end
end
