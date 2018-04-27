module Quartz
  # The `TimePoint` data type represents points in simulated time, and is
  # intended to be used internally.
  #
  # Its main purpose is to describe event times as offsets from a common
  # reference point. It may be perturbed by a `Duration` value.
  #
  # It is implemented as an arbitrary-precision integer, and provides only
  # relevant methods.
  #
  # The modeller should only manipulate `Duration` values.
  #
  # **TODO**:
  #   - handle sign.
  #   - one zero representation.
  #   - make immutable
  #   - transform mod operations by bit masking (e.g.  (n & (BASE-1)))
  struct TimePoint
    include Comparable(self)

    # The base of the simulated arithmetic.
    private BASE = Scale::FACTOR.to_i16

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

      coarsen! if @magnitude.size > 1
    end

    # Creates a new `TimePoint`, whose value is given by *numbers*, initialized at
    # the given *precision*.
    #
    # The *numbers* must be ordered and organized from the most-significant number
    # to the least-significant number.
    def initialize(*numbers : Int, @precision : Scale = Scale::BASE)
      @magnitude = numbers.reverse.map(&.abs.to_i16).to_a
    end

    # Creates a new `TimePoint`, whose value depends on the given *magnitude,
    # initialized at the given *precision*.
    #
    # The *magnitude* must be ordered and organized from the least-significant
    # number to the least-signifiant number.
    def initialize(@magnitude : Array(Int16), @precision : Scale)
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

    # Returns a shallow copy of `self`.
    def dup
      TimePoint.new(@magnitude.dup, @precision)
    end

    # Returns the integer corresponding to the indicated precision, or zero if
    # not in bounds.
    def [](scale : Scale) : Int16
      at(scale) { 0_i16 }
    end

    # Returns the integer corresponding to the indicated precision, or `nil`.
    def []?(scale : Scale) : Int16?
      at(scale) { nil }
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
      dup.advance(duration, truncate: false)
    end

    # Returns a new `TimePoint` to which the given `Duration` is subtracted.
    #
    # Doesn't truncate result to the duration precision.
    def -(duration : Duration) : TimePoint
      dup.advance(-duration, truncate: false)
    end

    # Measure the difference between `self` and another instance of `self`.
    # The difference is expressed by a `Duration` value.
    #
    # If the exact difference between the time points cannot be represented, an
    # infinite `Duration` is returned.
    #
    # See also `#gap`.
    def -(other : TimePoint) : Duration
      difference with: other, approximate: false
    end

    # Measure the difference between `self` and another instance of `self`.
    # The difference is expressed by a `Duration` value.
    #
    # If the exact difference between the time points cannot be represented, an
    # approximation is returned.
    #
    # See also `#-`.
    def gap(other : TimePoint) : Duration
      difference with: other, approximate: true
    end

    # Computes the difference between two instances of `self`.
    private def difference(with other : TimePoint, approximate : Bool) : Duration
      little, big = (@precision < other.precision) ? {self, other} : {other, self}
      diff = @precision - other.precision
      count = Math.max(diff + big.size, little.size)

      if diff > Duration::EPOCH && !approximate
        return Duration::INFINITY
      end

      precision = little.precision + Math.max(0, count - Duration::EPOCH - 1)

      truncated = precision - little.precision
      result_precision = precision

      multiplier = 0_i64
      carry = 0_i64
      exponent = 0

      (count - truncated).times do |i|
        carry += if i < little.size - truncated
                   self[precision + i] - other[precision + i]
                 else
                   big[precision + i]
                 end

        n = (carry % BASE) * BASE.to_i64 ** exponent

        # check overflow
        if (n > Duration::MULTIPLIER_MAX - multiplier)
          if approximate
            result_precision += 1
            exponent -= 1
            n /= BASE
            multiplier /= BASE
          else
            return Duration.new(Duration::MULTIPLIER_INFINITE, precision)
          end
        end

        multiplier += n
        carry = carry / BASE
        exponent += 1
      end

      Duration.new(multiplier, result_precision)
    end

    # Convert this `TimePoint` to an `Int64`.
    #
    # Note: this conversion can lose information about the overall magnitude of
    # `self` as well as return a result with the opposite sign.
    def to_i64
      n = 0_i64
      @magnitude.each_with_index(0) do |digit, i|
        n += digit.to_i64 * BASE.to_i64 ** (@precision.level.abs + i)
      end
      n
    end

    # Convert this `TimePoint` to an `Int32`.
    #
    # Note: this conversion can lose information about the overall magnitude of
    # `self` as well as return a result with the opposite sign.
    def to_i32
      to_i64.to_i32
    end

    def to_i
      to_i32
    end

    # Convert this `TimePoint` to a `BigInt`.
    def to_big_i
      str = String.build do |io|
        a.reverse_each { |digit| io.printf("%03d", digit) }
      end
      BigInt.new(str, BASE.to_i)
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
          lhs = self[precision]
          rhs = other[precision]
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

    def to_s(io)
      if zero?
        io << '0'
      else
        @magnitude.reverse_each.join("_", io)
      end
      if @precision.level != 0
        io << 'e'
        io << (@precision.level < 0 ? '-' : '+')
        io << (@precision.level * 3).abs
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
