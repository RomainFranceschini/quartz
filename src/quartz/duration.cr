module Quartz
  # `Duration` is a fixed-point time data type which encapsulates a 64-bit
  # binary floating-point number.
  struct Duration
    include Comparable(self)

    # The *epoch constant* helps establishing the limiting multiplier of the
    # `Duration` datatype together with `Scale::FACTOR`.
    EPOCH = 5

    # The limiting multiplier of the `Duration` type.
    #
    # The 1000^5 limit is chosen as the largest power of 1000 less than 2^53, the
    # point at which `Float64` ceases to exactly represent all integers.
    MULTIPLIER_MAX = Scale::FACTOR ** EPOCH

    # An infinite duration
    INFINITY = new(Float64::INFINITY)

    @fixed : Bool = false
    getter precision : Scale = Scale::BASE
    @multiplier : Float64

    def initialize(m : Number = 0i64, @precision : Scale = Scale::BASE, @fixed : Bool = false)
      @multiplier = if m >= MULTIPLIER_MAX
                      Float64::INFINITY
                    elsif m <= -MULTIPLIER_MAX
                      -Float64::INFINITY
                    elsif m.is_a?(Float)
                      m.round
                    else
                      m.to_f64
                    end
    end

    # Returns the multiplier of `self`.
    def multiplier : Int64
      case @multiplier
      when Float64::INFINITY
        Int64::MAX
      when -Float64::INFINITY
        Int64::MIN
      else
        @multiplier.to_i64
      end
    end

    # Whether `self` is a zero duration.
    def zero? : Bool
      @multiplier.zero?
    end

    # Whether `self` is a finite duration.
    def finite? : Bool
      !infinite?
    end

    # Whether `self` is an infinite duration.
    def infinite? : Bool
      @multiplier == Float64::INFINITY || @multiplier == -Float64::INFINITY
    end

    # Whether `self` fixed or unfixed. When fixed, the time precision is preserved
    # through operations. Otherwise, the time precision may be altered to minimize
    # rounding error.
    #
    # By default, `Duration` values are unfixed, which makes it easy to express
    # durations using combinations of multiples of base-1000 SI units.
    def fixed? : Bool
      @fixed
    end

    # Produces a duration value with the specified *precision* level.
    #
    # Neither fixes or unfixes the time precision of the result.
    def rescale(precision : Scale) : Duration
      m = @multiplier * (@precision / precision)
      Duration.new(m, precision, @fixed)
    end

    # Produces a fixed duration value with the specified *precision* level.
    def fixed_at(precision : Scale) : Duration
      m = @multiplier * (@precision / precision)
      Duration.new(m, precision, true)
    end

    # Produces an unfixed but equivalent duration.
    def unfixed : Duration
      Duration.new(@multiplier, @precision, false)
    end

    # Produces a fixed but equivalent duration.
    def fixed : Duration
      Duration.new(@multiplier, @precision, true)
    end

    # Adds two `Duration`s values.
    def +(other : Duration) : Duration
      precision = @precision
      m = if @fixed && other.fixed?
            if other.precision != @precision
              raise "Duration addition operation requires same precision level between operands."
            end
            @multiplier + other.multiplier
          elsif @fixed && !other.fixed?
            @multiplier + (other.multiplier * (other.precision / precision))
          elsif !@fixed && other.fixed?
            precision = other.precision
            (@multiplier * (@precision / precision)) + other.multiplier
          else
            tmp = if @precision < other.precision
                    @multiplier + (other.multiplier * (other.precision / precision))
                  elsif other.precision < @precision
                    precision = other.precision
                    (@multiplier * (@precision / precision)) + other.multiplier
                  else
                    @multiplier + other.multiplier
                  end
            # coarsen precision while multiplier overflows
            until -MULTIPLIER_MAX < tmp < MULTIPLIER_MAX
              precision += 1
              tmp /= Scale::FACTOR
            end
            tmp
          end
      Duration.new(m, precision, @fixed || other.fixed?)
    end

    # Substracts two `Duration`s values
    def -(other : Duration) : Duration
      precision = @precision
      m = if @fixed && other.fixed?
            if other.precision != @precision
              raise "Duration substraction operation requires same precision level between operands."
            end
            @multiplier - other.multiplier
          elsif @fixed && !other.fixed?
            @multiplier - (other.multiplier * (other.precision / @precision))
          elsif !@fixed && other.fixed?
            precision = other.precision
            (@multiplier * (@precision / other.precision)) - other.multiplier
          else
            tmp = if @precision < other.precision
                    @multiplier - (other.multiplier * (other.precision / @precision))
                  elsif other.precision < @precision
                    precision = other.precision
                    (@multiplier * (@precision / other.precision)) - other.multiplier
                  else
                    @multiplier - other.multiplier
                  end
            # coarsen precision while multiplier overflows
            until -MULTIPLIER_MAX < tmp < MULTIPLIER_MAX
              precision += 1
              tmp /= Scale::FACTOR
            end
            tmp
          end
      Duration.new(m, precision, @fixed || other.fixed?)
    end

    # Multiply `self` by the given factor *n*.
    def *(n : Number) : Duration
      m = @multiplier * n
      precision = @precision
      if @fixed
        m = m.round
      elsif n.abs < 1
        # while multiplier has a fractional part and precision refining doesn't overflow
        while (m % 1 > 0) && (m < MULTIPLIER_MAX / Scale::FACTOR) && (m > -MULTIPLIER_MAX / Scale::FACTOR)
          precision -= 1
          m *= Scale::FACTOR
        end
      else
        # coarsen precisison while multiplier overflows
        until -MULTIPLIER_MAX < m < MULTIPLIER_MAX
          precision += 1
          m /= Scale::FACTOR
        end
      end
      Duration.new(m, precision, @fixed)
    end

    # Divide `self` by the given scalar operand *n*.
    def /(n : Number) : Duration
      m = @multiplier / n
      precision = @precision
      if @fixed
        m = m.round
      elsif n.abs > 1
        # while multiplier has a fractional part and scale refining doesn't overflow
        while (m % 1 > 0) && (m < MULTIPLIER_MAX / Scale::FACTOR) && (m > -MULTIPLIER_MAX / Scale::FACTOR)
          precision -= 1
          m *= Scale::FACTOR
        end
      end
      Duration.new(m, precision, @fixed)
    end

    # Negates `self`.
    def - : Duration
      Duration.new(-@multiplier, @precision, @fixed)
    end

    # The division of one duration by another is always considered a
    # floating-point operation.
    #
    # The numerator and denominator may have different precision levels and the
    # result is a scalar with no prescribed precision.
    def /(other : Duration) : Float64
      (@multiplier / other.@multiplier) * (@precision / other.precision)
    end

    # Implements the comparison operator.
    #
    # Assumes that `self` and *other* could be replaced by their associated
    # quantities. As a consequence, two `Duration` values can be considered equal
    # with different precision levels.
    def <=>(other : self)
      if (@precision == other.precision) || (infinite? || other.infinite?)
        @multiplier <=> other.@multiplier
      else
        @multiplier <=> other.rescale(@precision).@multiplier
      end
    end

    # Equality — Returns `true` only if `self` and *other* are equivalent in both
    # multiplier and time precision.
    def equals?(other : self)
      @multiplier == other.@multiplier && @precision == other.precision
    end

    def to_s(io)
      if infinite?
        io << @multiplier
      else
        io << @multiplier.to_i64
        io << "x1e"
        io << @precision.level*3
      end
      io
    end
  end
end

struct ::Number
  def *(other : Duration)
    other * self
  end
end
