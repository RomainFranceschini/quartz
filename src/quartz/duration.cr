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
    # The 1000^5 limit is chosen as the largest power of 1000 less than 2^53,
    # the point at which `Float64` ceases to exactly represent all integers.
    MULTIPLIER_LIMIT = Scale::FACTOR ** EPOCH

    # The largest finite multiplier that can be represented by a `Duration`.
    MULTIPLIER_MAX = MULTIPLIER_LIMIT - 1

    # The smallest finite multiplier that can be represented by a `Duration`.
    MULTIPLIER_MIN = 0_i64

    # The infinite multiplier
    MULTIPLIER_INFINITE = Float64::INFINITY

    # An infinite duration with a base scale.
    INFINITY = new(MULTIPLIER_INFINITE)

    @fixed : Bool = false
    getter precision : Scale = Scale::BASE
    @multiplier : Float64

    def self.infinity(precision : Scale = Scale::BASE, fixed : Bool = false)
      new(MULTIPLIER_INFINITE, precision, fixed)
    end

    def self.zero(precision : Scale = Scale::BASE, fixed : Bool = false)
      new(0, precision, fixed)
    end

    def initialize(m : Number = 0i64, @precision : Scale = Scale::BASE, @fixed : Bool = false)
      @multiplier = if m >= MULTIPLIER_LIMIT
                      Float64::INFINITY
                    elsif m <= -MULTIPLIER_LIMIT
                      -Float64::INFINITY
                    elsif m.is_a?(Float)
                      if (m % 1 > 0) # if m has a fractional part
                        rounded = m.round
                        if rounded < -MULTIPLIER_MAX
                          m.ceil
                        elsif rounded > MULTIPLIER_MAX
                          m.floor
                        else
                          rounded
                        end
                      else
                        m
                      end
                    else
                      m.to_f64
                    end
    end

    def initialize(pull : ::JSON::PullParser)
      m = nil
      p = nil

      pull.read_object do |key|
        case key
        when "multiplier"
          m = pull.read_float
        when "precision"
          p = Scale.new(pull.read_int)
        else
          raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
        end
      end

      @multiplier = m.as(Float64)
      @precision = p.as(Scale)
    end

    def initialize(pull : ::MessagePack::Unpacker)
      pull.read_hash_size
      Bytes.new(pull)
      @multiplier = pull.read_uint.to_f64
      Bytes.new(pull)
      @precision = Scale.new(pull.read_uint)
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
            until -MULTIPLIER_LIMIT < tmp < MULTIPLIER_LIMIT
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
            until -MULTIPLIER_LIMIT < tmp < MULTIPLIER_LIMIT
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
        while (m % 1 > 0) && (m < MULTIPLIER_LIMIT // Scale::FACTOR) && (m > -MULTIPLIER_LIMIT // Scale::FACTOR)
          precision -= 1
          m *= Scale::FACTOR
        end
      else
        # coarsen precisison while multiplier overflows
        until -MULTIPLIER_LIMIT < m < MULTIPLIER_LIMIT
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
        while (m % 1 > 0) && (m < MULTIPLIER_LIMIT // Scale::FACTOR) && (m > -MULTIPLIER_LIMIT // Scale::FACTOR)
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
      (@multiplier / other.multiplier) * (@precision / other.precision)
    end

    # Implements the comparison operator.
    #
    # Assumes that `self` and *other* could be replaced by their associated
    # quantities. As a consequence, two `Duration` values can be considered equal
    # with different precision levels.
    def <=>(other : self)
      if (@precision == other.precision) || (infinite? || other.infinite?)
        multiplier <=> other.multiplier
      elsif @precision < other.precision
        multiplier <=> other.rescale(@precision).multiplier
      else
        rescale(other.precision).multiplier <=> other.multiplier
      end
    end

    # Equality — Returns `true` only if `self` and *other* are equivalent in both
    # multiplier and time precision.
    def equals?(other : self)
      multiplier == other.multiplier && @precision == other.precision
    end

    def inspect(io)
      if infinite?
        io << @multiplier
      else
        io << @multiplier.to_i64
        if @precision.level != 0
          io << 'e'
          io << (@precision.level < 0 ? '-' : '+')
          io << (@precision.level * 3).abs
        end
      end
      io << (@fixed ? "_fd" : "_ud")
      io
    end

    def to_f64
      @multiplier * @precision.to_f64
    end

    def to_f32
      @multiplier.to_f32 * @precision.to_f32
    end

    def to_f
      to_f64
    end

    def to_json(json : ::JSON::Builder)
      json.object do
        json.field("multiplier") { @multiplier.to_json(json) }
        json.field("precision") { @precision.level.to_json(json) }
      end
    end

    def to_msgpack(packer : ::MessagePack::Packer)
      packer.write_hash_start(2)

      packer.write("multiplier")
      packer.write(multiplier)
      packer.write("precision")
      packer.write(@precision.level)
    end
  end

  ALLOWED_SCALE_UNITS = [
    "yocto", "zepto", "atto", "femto", "pico", "nano", "micro", "milli", "base",
    "kilo", "mega", "giga", "tera", "peta", "exa", "zetta", "yotta",
  ]

  # The `duration` macro is syntax sugar to construct a new `Duration` struct.
  #
  # ### Usage
  #
  # `duration` must receive a number literal along with an optional scale unit.
  # The scale unit can be specified with a constant expression (e.g. 'kilo'), or
  # with a `Scale` struct.
  #
  # ```
  # duration(2)                # => Duration.new(2, Scale::BASE)
  # duration(2, Scale.new(76)) # => Duration.new(2, Scale.new(76))
  # duration(2, Scale::KILO)   # => Duration.new(2, Scale::KILO)
  # duration(2, kilo)          # => Duration.new(2, Scale::KILO)
  # ```
  #
  # If specified with a constant expression, the unit argument can be a string
  # literal, a symbol literal or a plain name.
  #
  # ```
  # duration(2, kilo)
  # duration(2, 'kilo')
  # duration(2, :kilo)
  # ```
  macro duration(length, unit = "base")
    {% if ALLOWED_SCALE_UNITS.includes?(unit.id.stringify) %}
      Quartz::Duration.new({{length}}, Quartz::Scale::{{ unit.id.upcase }})
    {% else %}
      Quartz::Duration.new({{length}}, {{unit}})
    {% end %}
  end
end

struct ::Number
  def *(other : Quartz::Duration)
    other * self
  end
end

struct ::Int
  def duration_units
    Quartz::Duration.new(self, Quartz::Scale::BASE)
  end

  def yocto_duration_units
    Quartz::Duration.new(self, Quartz::Scale::YOCTO)
  end

  def zepto_duration_units
    Quartz::Duration.new(self, Quartz::Scale::ZEPTO)
  end

  def atto_duration_units
    Quartz::Duration.new(self, Quartz::Scale::ATTO)
  end

  def femto_duration_units
    Quartz::Duration.new(self, Quartz::Scale::FEMTO)
  end

  def pico_duration_units
    Quartz::Duration.new(self, Quartz::Scale::PICO)
  end

  def nano_duration_units
    Quartz::Duration.new(self, Quartz::Scale::NANO)
  end

  def micro_duration_units
    Quartz::Duration.new(self, Quartz::Scale::MICRO)
  end

  def milli_duration_units
    Quartz::Duration.new(self, Quartz::Scale::MILLI)
  end

  def kilo_duration_units
    Quartz::Duration.new(self, Quartz::Scale::KILO)
  end

  def mega_duration_units
    Quartz::Duration.new(self, Quartz::Scale::MEGA)
  end

  def giga_duration_units
    Quartz::Duration.new(self, Quartz::Scale::GIGA)
  end

  def tera_duration_units
    Quartz::Duration.new(self, Quartz::Scale::TERA)
  end

  def peta_duration_units
    Quartz::Duration.new(self, Quartz::Scale::PETA)
  end

  def exa_duration_units
    Quartz::Duration.new(self, Quartz::Scale::EXA)
  end

  def zetta_duration_units
    Quartz::Duration.new(self, Quartz::Scale::ZETTA)
  end

  def yotta_duration_units
    Quartz::Duration.new(self, Quartz::Scale::YOTTA)
  end
end
