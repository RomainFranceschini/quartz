require "./spec_helper"

class MyCoupled < CoupledModel
  def initialize(name)
    super(name)

    self << AtomicModel.new("a")
    self << AtomicModel.new("b")
    self << AtomicModel.new("c")
  end
end

describe "ProcessorAllocator" do
  it "allocates appropriate processors across whole hierarchy" do
    coupled = MyCoupled.new("root")
    coupled << DSDE::CoupledModel.new("dynamic")
    nested = MyCoupled.new("nested")
    coupled << nested
    coupled << MultiComponent::Model.new("multipdevs")

    sim = Simulation.new(coupled)
    visitor = ProcessorAllocator.new(sim, coupled)

    coupled.accept(visitor)

    coupled.processor.should be_a(RootCoordinator)
    coupled["a"].processor.should be_a(Simulator)
    coupled["b"].processor.should be_a(Simulator)
    coupled["c"].processor.should be_a(Simulator)

    nested.processor.should be_a(Coordinator)
    nested["a"].processor.should be_a(Simulator)
    nested["b"].processor.should be_a(Simulator)
    nested["c"].processor.should be_a(Simulator)

    coupled["dynamic"].processor.should be_a(DSDE::Coordinator)
    coupled["multipdevs"].processor.should be_a(MultiComponent::Simulator)
  end

  it "visit all children except multipdevs ones and atomics" do
    coupled = MyCoupled.new("root")
    dsde = DSDE::CoupledModel.new("dynamic")
    coupled << dsde
    multi = MultiComponent::Model.new("multipdevs")
    coupled << multi

    sim = Simulation.new(coupled)
    visitor = ProcessorAllocator.new(sim, coupled)

    visitor.visit_children?(multi).should be_false
    visitor.visit_children?(coupled).should be_true
    visitor.visit_children?(dsde).should be_true
    visitor.visit_children?(coupled["a"]).should be_false
  end

  it "allocates processors of newcomers" do
    coupled = MyCoupled.new("root")
    sim = Simulation.new(coupled)
    root_coordinator = RootCoordinator.new(coupled, sim)

    visitor = ProcessorAllocator.new(sim, root_coordinator)
    newcomer = AtomicModel.new("new")
    coupled << newcomer

    visitor.accept(newcomer)
    newcomer.processor.should be_a(Simulator)
  end
end
