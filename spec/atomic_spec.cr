require "./spec_helper"

private class FetchOutputTest < AtomicModel
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
  state_var x : Int32 = 0
  state_var y : Int32 = 0

  @sigma = Duration.new(25)

  def evolve
    @x = 100
    @y = 254
  end
end

private class MockProcessor < Processor
  def initialize_processor(time)
    {Duration.new(0), Duration.new(0)}
  end

  def collect_outputs(time)
    Hash(OutputPort, Any).new
  end

  def perform_transitions(planned, elapsed)
    Duration.new(0, Scale::BASE)
  end
end

describe "AtomicModel" do
  describe "#post" do
    it "raises when dropping a value on a port of another model" do
      foo = AtomicModel.new("foo")
      bar = AtomicModel.new("bar")
      bop = bar.add_output_port("out")

      expect_raises InvalidPortHostError do
        foo.post("test", bop)
      end
    end

    it "raises when port name doesn't exist" do
      foo = AtomicModel.new("foo")
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
      m.fetch_output![m.output_port("out")].should eq("a value")
      m.calls.should eq(1)
    end
  end

  describe "serialization" do
    it "can be converted to JSON" do
      m = ModelSample.new("foo", ModelSample::State.new(x: 5, y: 10))
      m.to_json.should eq "{\"name\":\"foo\",\"state\":{\"x\":5,\"y\":10},\"sigma\":{\"multiplier\":25.0,\"precision\":0}}"
    end

    it "can be converted to msgpack" do
      m = ModelSample.new("foo", ModelSample::State.new(x: 5, y: 10))
      m.to_msgpack.should eq Bytes[132, 164, 110, 97, 109, 101, 163, 102, 111, 111, 165, 115, 116, 97, 116, 101, 130, 161, 120, 5, 161, 121, 10, 165, 115, 105, 103, 109, 97, 130, 170, 109, 117, 108, 116, 105, 112, 108, 105, 101, 114, 25, 169, 112, 114, 101, 99, 105, 115, 105, 111, 110, 0]
    end
  end

  describe "deserialization" do
    it "can be initialized from JSON" do
      io = IO::Memory.new("{\"name\":\"foo\",\"state\":{\"x\":5,\"y\":10},\"sigma\":{\"multiplier\":1.0,\"precision\":0}}")
      m = ModelSample.new(JSON::PullParser.new(io))
      m.name.should eq("foo")
      m.sigma.should eq Duration.new(1)
      m.x.should eq 5
      m.y.should eq 10
    end

    it "can be initialized from msgpack" do
      io = IO::Memory.new(Bytes[131, 164, 110, 97, 109, 101, 163, 102, 111, 111, 165, 115, 116, 97, 116, 101, 130, 161, 120, 5, 161, 121, 10, 165, 115, 105, 103, 109, 97, 130, 170, 109, 117, 108, 116, 105, 112, 108, 105, 101, 114, 1, 169, 112, 114, 101, 99, 105, 115, 105, 111, 110, 0])
      m = ModelSample.new(MessagePack::Unpacker.new(io))
      m.name.should eq "foo"
      m.sigma.should eq Duration.new(1)
      m.x.should eq 5
      m.y.should eq 10
    end
  end
end
