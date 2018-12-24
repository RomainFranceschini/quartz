require "./spec_helper"

private class SimpleModel < AtomicModel
  include PassiveBehavior
end

describe "Simulation" do
  describe "initialization" do
    it "accepts an atomic model" do
      Simulation.new(SimpleModel.new("am"))
    end

    it "is in waiting status" do
      sim = Simulation.new(SimpleModel.new("am"))
      sim.ready?.should be_true
      sim.done?.should be_false
      sim.running?.should be_false
      sim.status.should eq(Simulation::Status::Ready)
    end
  end
end
