require "./spec_helper"

private class PassiveModel < AtomicModel
  include PassiveBehavior
end

private class FetchOutputTest < AtomicModel
  include PassiveBehavior

  def initialize
    super("fetch_output")
    add_output_port "out"
  end

  getter calls : Int32 = 0

  def output
    post("a value", on: "out")
    @calls += 1
  end
end

class ModelSample < AtomicModel
  include PassiveBehavior

  state x : Int32 = 0, y : Int32 = 0

  def time_advance : Duration
    Duration.new(25)
  end

  def evolve
    self.x = 100
    self.y = 254
  end
end

private class MockProcessor < Processor
  include Schedulable

  def initialize_processor(time) : {Duration, Duration}
    {Duration.new(0), Duration.new(0)}
  end

  def collect_outputs(time) : Hash(OutputPort, Array(Any))
    Hash(OutputPort, Array(Any)).new
  end

  def perform_transitions(planned, elapsed) : Duration
    Duration.new(0, Scale::BASE)
  end
end

private class PreciseModel < AtomicModel
  include PassiveBehavior

  precision femto
end

describe "AtomicModel" do
  describe "#post" do
    it "raises when dropping a value on a port of another model" do
      foo = PassiveModel.new("foo")
      bar = PassiveModel.new("bar")
      bop = bar.add_output_port("out")

      expect_raises InvalidPortHostError do
        foo.post("test", bop)
      end
    end

    it "raises when port name doesn't exist" do
      foo = PassiveModel.new("foo")
      expect_raises NoSuchPortError do
        foo.post("test", "out")
      end
    end
  end

  describe "#initialize" do
    it "can be initialized using its state" do
      m = ModelSample.new("foo", ModelSample::State.new(x: 1, y: 2))
      m.x.should eq 1
      m.y.should eq 2
    end
  end

  describe "precision" do
    it "can be changed using a macro at class-level" do
      PreciseModel.precision_level.should eq(Scale::FEMTO)
    end

    it "can be changed externally" do
      PreciseModel.precision_level = Scale::TERA
      PreciseModel.precision_level.should eq(Scale::TERA)
    end
  end

  describe "simulation parameters initialization" do
    it "uses initial state to set its state before running a simulation" do
      m = ModelSample.new("foo")
      m.x.should eq 0
      m.y.should eq 0

      m.initial_state = ModelSample::State.new(x: 5, y: 10)
      m.x.should eq 0
      m.y.should eq 0

      p = MockProcessor.new(m)
      m.__initialize_state__(p)

      m.x.should eq 5
      m.y.should eq 10
    end

    it "uses default state if no initial state is specified before running a simulation" do
      m = ModelSample.new("foo")
      m.x.should eq 0
      m.y.should eq 0
      p = MockProcessor.new(m)

      m.evolve

      m.x.should eq 100
      m.y.should eq 254

      m.__initialize_state__(p)
      m.x.should eq 0
      m.y.should eq 0
    end

    it "raises if wrong processor asks initialization" do
      m = ModelSample.new("foo")
      p1 = MockProcessor.new(m)
      p2 = MockProcessor.new(m)
      expect_raises InvalidProcessorError do
        m.__initialize_state__(p1)
      end
    end
  end

  describe "fetch_output!" do
    it "calls #output" do
      m = FetchOutputTest.new
      m.fetch_output![m.output_port("out")].should eq(["a value"])
      m.calls.should eq(1)
    end
  end
end
