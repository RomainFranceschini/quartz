require "./test_helper"

class GenTestError < Exception; end

def fail_unless(passes : Bool)
  raise GenTestError.new if passes == false
end

class TestGen < DEVS::AtomicModel
  getter output_calls : Int32 = 0
  getter internal_calls : Int32 = 0

  def output
    @output_calls += 1
  end

  def time_advance
    1
  end

  def internal_transition
    @internal_calls += 1
    fail_unless @elapsed == 0
    fail_unless @time == @internal_calls-1
  end
end

gen = TestGen.new(:testgen)
sim = DEVS::Simulation.new(gen, duration: 10)

sim.each_with_index do |_, i|
  fail_unless gen.output_calls == i+1
  fail_unless gen.internal_calls == i+1
  fail_unless gen.time == i+1
end

fail_unless gen.output_calls == 9
fail_unless gen.internal_calls == 9
fail_unless gen.time == 9

puts "test generator --> OK"
