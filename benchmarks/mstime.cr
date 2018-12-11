require "benchmark"
require "big"
require "../src/quartz"

tp = Quartz::TimePoint.new(0)
fp = 0.0f64
bi = BigInt.new(0)
bf = BigFloat.new(0)

n = 100_000_000

# Monkey patch BigInt addition to mutate self instead of allocating a new mpz (perf boost but dangerous).
# Comment this method to restore original performance of BigInt.
# struct BigInt
#   def +(other : Int) : BigInt
#     if other < 0
#       self - other.abs
#     else
#       LibGMP.add_ui(mpz, self, other) # mutate self!
#       self
#     end
#   end
# end

Benchmark.bm do |x|
  x.report("fp64") { n.times { fp = fp + 1.064 } }
  x.report("bigi") { n.times { bi = bi + 1 } }
  x.report("bigf") { n.times { bf = bf + 1 } }
  x.report("timepoint") { n.times { tp.advance by: Quartz::Duration.new(1) } }
end
