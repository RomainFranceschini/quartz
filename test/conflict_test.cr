require "./test_helper"

class ConflictTestError < Exception; end

def fail_unless(passes : Bool)
  raise ConflictTestError.new if passes == false
end

class G < DEVS::AtomicModel
  def initialize(name)
    super(name)
    @sigma = 1
    add_output_port :out
  end

  getter output_calls : Int32 = 0
  getter int_calls : Int32 = 0

  def output
    @output_calls += 1
    post "value", :out
  end

  def internal_transition
    @int_calls += 1
    @sigma = DEVS::INFINITY
  end
end

class R < DEVS::AtomicModel
  def initialize(name)
    super(name)
    @sigma = 1
    add_input_port :in
  end

  getter con_calls : Int32 = 0
  getter output_calls : Int32 = 0

  def external_transition(bag)
    raise ConflictTestError.new
  end

  def confluent_transition(bag)
    @con_calls += 1
    fail_unless @elapsed == 0
    fail_unless bag[input_port(:in)] == ["value"]
    @sigma = DEVS::INFINITY
  end

  def internal_transition
    raise ConflictTestError.new
  end

  def output
    @output_calls += 1
  end
end

class TestPDEVSDeltaCon < DEVS::CoupledModel
  getter g, r

  def initialize
    super("test_pdevs_delta_con")

    @r = R.new :R
    @g = G.new :G

    self << @r << @g

    attach(:out, to: :in, between: :G, and: :R)
  end
end

def pass?(m)
  fail_unless m.r.con_calls == 1
  fail_unless m.g.int_calls == 1
  fail_unless m.g.output_calls == 1
end

m = TestPDEVSDeltaCon.new
sim = DEVS::Simulation.new(m, maintain_hierarchy: true)
sim.simulate
pass?(m)
puts "test pdevs delta con --> OK"

m = TestPDEVSDeltaCon.new
sim = DEVS::Simulation.new(m, maintain_hierarchy: false)
sim.simulate
pass?(m)
puts "test pdevs delta con flattening --> OK"
