
module Quartz
  module Comparison
    REL_TOLERANCE = 1e-8
    ABS_TOLERANCE = 1e-6

    # Float32 use 23 bits for the mantissa (6 to 9 decimal digits)
    # Float64 use 52 bits for the mantissa (15 to 17 decimal digits)

    def near_abs?(other, abs_eps = ABS_TOLERANCE)
      (self - other).abs <= abs_eps
    end

    def near_rel?(other, rel_eps = REL_TOLERANCE)
      diff = (self - other).abs
      aa = abs
      ab = other.abs
      largest = (ab > aa) ? ab : aa
      diff <= largest * rel_eps
    end

    def near?(other, abs_eps = ABS_TOLERANCE, rel_eps = REL_TOLERANCE)
      diff = (self - other).abs
      return true if other == self || diff <= abs_eps
      aa = abs
      ab = other.abs
      largest = (ab > aa) ? ab : aa
      diff <= largest * rel_eps
    end

    def epsilon(scale : Int = DEFAULT_SCALE)
      1.0 / 10**scale
    end
  end
end

struct Float64
  include Quartz::Comparison
end
