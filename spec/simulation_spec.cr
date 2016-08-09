require "./spec_helper"

#class SimpleModel < AtomicModel
#end

describe "Simulation" do

  describe "initialization" do
    it "accepts an atomic model" do
      Simulation.new(AtomicModel.new("am"))
    end

    it "is in waiting status" do
      sim = Simulation.new(AtomicModel.new("am"))
      sim.waiting?.should be_true
      sim.done?.should be_false
      sim.running?.should be_false
      sim.status.should eq(:waiting)
    end
  end



end
