module Quartz
  # The `TimePoint` data type represents points in simulated time. It is
  # intended internally. The modeller only has to manipulate `Duration` values.
  #
  # Its main purpose is to describe event times as offsets from a common
  # reference point. It may be perturbed by a `Duration` value.
  #
  # It is implemented as an arbitrary-precision integer, and provides only
  # relevant methods.
  #
  # **TODO**:
  #   - handle sign.
  #   - one zero representation.
  #   - make immutable
  #   - transform mod operations by bit masking (e.g.  (n & (BASE-1)))
  struct TimePoint
    include Comparable(self)

    # The base of the simulated arithmetic.
    private BASE = 1000_i16

    # The `TimePoint` constant zero.
    ZERO = new(0, Scale::BASE)

    # Returns the precision associated with the least significant number.
    getter precision : Scale

    # The magnitude of this `TimePoint`, stored in *little-endian*: the zeroth
    # element of this array is the least-significant integer of the magnitude.
    # Each integer is a base-1000 number.
    # A zero `TimePoint` has a zero-length magnitude array.
    @magnitude : Array(Int16)

    # Creates a new `TimePoint` value, initialized at the given *precision* from
    # the given integer *n*, which may or not be zero.
    def initialize(n : Int = 0, @precision : Scale = Scale::BASE)
      n = n.abs
      @magnitude = [] of Int16

      while n != 0
        @magnitude << (n % BASE).to_i16
        n /= BASE
      end
    end

    # Creates a new `TimePoint`, whose value is given by *numbers*, initialized at
    # the given *precision*, and given *sign*.
    #
    # The *numbers* must be ordered and organized from the most-significant number
    # to the least-significant number.
    def initialize(*numbers : Int, @precision : Scale = Scale::BASE)
      @magnitude = numbers.reverse.map(&.abs.to_i16).to_a
    end

    # Whether `self` is a zero time point value.
    def zero?
      @magnitude.all? &.zero?
    end

    # Returns the order of magnitude of `self`, based on its `#precision`
    # and the number of stored integers on a base-1000 scale.
    def size
      @magnitude.size
    end

    # Returns the integer corresponding to the indicated precision, raises otherwise.
    def [](scale : Scale) : Int16
      if @precision <= scale < (@precision + @magnitude.size)
        @magnitude[scale - @precision]
      else
        raise IndexError.new
      end
    end

    # Returns the integer corresponding to the indicated precision, or `nil`.
    def []?(scale : Scale) : Int16?
      if @precision <= scale < (@precision + @magnitude.size)
        @magnitude[scale - @precision]
      else
        nil
      end
    end

    # Returns the element at the given *precision*, if in bounds,
    # otherwise executes the given block and returns its value.
    def at(scale : Scale)
      if @precision <= scale < (@precision + @magnitude.size)
        @magnitude[scale - @precision]
      else
        yield
      end
    end

    # Returns the integer at the corresponding index following the little-endian
    # representation (0 is the least significant).
    #
    # Raises if the given index is not in bounds.
    def [](i : Int) : Int16
      @magnitude[i]
    end

    # Returns the integer at the corresponding index following the little-endian
    # representation (0 is the least significant).
    #
    # Returns `nil` if given index is not in bounds.
    def []?(i : Int) : Int16?
      @magnitude[i]?
    end

    # Returns the element at the given *index*, if in bounds,
    # otherwise executes the given block and returns its value.
    def at(index : Int, &block : -> Int16)
      @magnitude.at(index, &block)
    end

    # Multiscale advancement - Adds the given `Duration` to `self`.
    #
    # If the advancement duration is zero, returns `self`. Advances according to
    # the duration value otherwise.
    #
    # If the *truncate* parameter is set to `true`, the time point is truncated
    # at the precision level of the duration (e.g. all digits less significant are
    # discarded). Otherwise, yields exact results.
    #
    # See also `#+`, `#-`.
    def advance(by duration : Duration, truncate : Bool = true) : TimePoint
      precision = duration.precision
      if duration.zero?
        return self
      end

      if precision < @precision
        refine_to!(precision)
      elsif @precision < precision
        coarse_to!(precision) if truncate
        expand_to!(precision)
      elsif zero?
        @precision = precision
      end

      multiplier = duration.multiplier
      i = @precision - precision

      if multiplier > 0
        carry = 0_i64
        while multiplier != 0 || carry != 0
          n = (multiplier % BASE)
          if i == @magnitude.size
            @magnitude << 0_i16
          end

          carry += @magnitude[i] + n
          @magnitude[i] = (carry % BASE).to_i16

          carry = carry / BASE
          multiplier = multiplier / BASE
          i += 1
        end
        coarsen! if @magnitude[0] == 0_i16
      else
        carry = 0_i64
        multiplier = multiplier.abs
        while multiplier != 0 || carry != 0
          n = (multiplier % BASE)

          carry = carry + @magnitude[i] - n
          @magnitude[i] = (carry % BASE).to_i16

          carry = carry / BASE
          multiplier = multiplier / BASE
          i += 1
        end
        coarsen! if @magnitude[0] == 0_i16
        trim! if @magnitude.last == 0_i16
      end

      self
    end

    # Returns a new `TimePoint` to which the given `Duration` is added.
    #
    # Doesn't truncate result to the duration precision.
    def +(duration : Duration) : TimePoint
      self.dup.advance(duration, truncate: false)
    end

    # Returns a new `TimePoint` to which the given `Duration` is subtracted.
    #
    # Doesn't truncate result to the duration precision.
    def -(duration : Duration) : TimePoint
      self.dup.advance(-duration, truncate: false)
    end

    # Measure the difference between `self` and another instance of `self`.
    # The difference is expressed by a `Duration` value.
    #
    # If the exact difference between the time points cannot be represented, an
    # infinite `Duration` is returned.
    #
    # See also `#gap`.
    def -(other : TimePoint) : Duration
      if (@precision - other.precision) > Duration::EPOCH
        Duration::INFINITY
      else
        multiplier, precision = difference(with: other)
        Duration.new(multiplier, precision)
      end
    end

    # Measure the difference between `self` and another instance of `self`.
    # The difference is expressed by a `Duration` value.
    #
    # If the exact difference between the time points cannot be represented, an
    # approximation is returned.
    #
    # See also `#-`.
    def gap(other : TimePoint) : Duration
      if (@precision - other.precision) > Duration::EPOCH
        if other.precision < @precision
          other.coarse_to!(other.precision + (((@precision - other.precision) - Duration::EPOCH)))
        else
          self.coarse_to!(@precision + (((@precision - other.precision) - Duration::EPOCH)))
        end
      end

      multiplier, precision = difference(with: other)

      until multiplier < Duration::MULTIPLIER_MAX
        multiplier /= BASE
        precision += 1
      end

      Duration.new(multiplier, precision)
    end

    # Computes the difference between two instances of `self`.
    private def difference(with other : TimePoint) : {Int64, Scale}
      multiplier = 0_i64
      carry = 0_i64

      diff = (@precision - other.precision)
      little, big = (@precision < other.precision) ? {self, other} : {other, self}
      precision = little.precision

      Math.max(diff + big.size - 1, little.size).times do |i|
        carry += if i < little.size
                   self.at(precision) { 0_i16 } - other.at(precision) { 0_i16 }
                 else
                   big.at(precision) { 0_i16 }
                 end
        multiplier += (carry % BASE).to_i64 * BASE.to_i64 ** i
        carry = carry / BASE
        precision += 1
      end

      multiplier += carry

      {multiplier, little.precision}
    end

    # Convert this `TimePoint`to an `Int64`.
    #
    # Note: this conversion can lose information about the overall magnitude of
    # `self` as well as return a result with the opposite sign.
    def to_i64
      n = 0_i64
      @magnitude.each_with_index(0) { |digit, i|
        n += digit.to_i64 * BASE.to_i64 ** (@precision.level.abs + i)
      }
      n
    end

    # Comparison operator
    def <=>(other : TimePoint)
      compare_magnitudes(other)
    end

    private def compare_magnitudes(other : TimePoint)
      diff = (@precision - other.precision)
      precision = @precision
      lhs_size, rhs_size = if @precision < other.precision
                             {self.size, diff + other.size}
                           else
                             precision = other.precision
                             {diff + self.size, other.size}
                           end

      if lhs_size < rhs_size
        -1
      elsif lhs_size > rhs_size
        1
      else
        # lengths are equal, compare the values
        cmp = 0
        Math.max(lhs_size, rhs_size).times do
          lhs = self.at(precision) { 0_i16 }
          rhs = other.at(precision) { 0_i16 }
          if lhs < rhs
            cmp = -1
            break
          elsif lhs > rhs
            cmp = 1
            break
          end
          precision += 1
        end
        cmp
      end
    end

    # Removes trailing zeros from the most significant digits.
    private def trim!
      while @magnitude.last == 0_i16 && @magnitude.size > 1
        @magnitude.pop
      end
    end

    # Removes trailing zeros from the least significant digits.
    private def coarsen!
      while @magnitude.first == 0_i16 && @magnitude.size > 1
        @magnitude.shift
        @precision += 1_i8
      end
    end

    # Discards all digits less significant than *given* precision.
    def coarse_to!(precision : Scale)
      diff = (precision - @precision)
      @precision = precision
      if diff < @magnitude.size
        diff.times { @magnitude.shift }
      end
    end

    # Refines `self` to match given precision.
    private def refine_to!(precision : Scale)
      diff = (precision - @precision)
      @precision = precision
      unless zero?
        diff.times { @magnitude.unshift(0_i16) }
      end
    end

    # Expands `self` to represent digits up to given precision.
    #
    # Doesn't change the original precision.
    private def expand_to!(precision : Scale)
      (@precision - precision).times { @magnitude.push(0_i16) }
    end
  end
end
