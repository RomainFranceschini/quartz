require "./spec_helper"
require "../src/quartz/json"

private class ModelSample < AtomicModel
  include PassiveBehavior

  state do
    var x : Int32 = 0
    var y : Int32 = 0
  end

  def time_advance : Duration
    Duration.new(25)
  end

  def evolve
    self.x = 100
    self.y = 254
  end
end

private struct SomeModel
  include Stateful

  state do
    var a : Int32 = 42
    var b : String = "foo"
    var c : Bool = false
  end
end

private class Point2d
  include JSON::Serializable
  include Stateful

  state do
    var x : Int32 = 0
    var y : Int32 = 0
  end
end

private class Point3d < Point2d
  state { var z : Int32 = 0 }

  def xyz
    {x, y, z}
  end
end

describe "AtomicModel" do
  describe "serialization" do
    it "can be converted to JSON" do
      m = ModelSample.new("foo", ModelSample::State.new(x: 5, y: 10))
      m.to_json.should eq "{\"name\":\"foo\",\"state\":{\"x\":5,\"y\":10},\"initial_state\":{\"x\":0,\"y\":0},\"elapsed\":{\"fixed\":false,\"precision\":{\"level\":0},\"multiplier\":0.0}}"
    end
  end

  describe "deserialization" do
    it "can be initialized from JSON" do
      io = IO::Memory.new("{\"name\":\"foo\",\"state\":{\"x\":5,\"y\":10},\"initial_state\":{\"x\":0,\"y\":0},\"elapsed\":{\"fixed\":false,\"precision\":{\"level\":0},\"multiplier\":0.0}}")
      m = ModelSample.new(JSON::PullParser.new(io))
      m.name.should eq("foo")
      m.time_advance.should eq Duration.new(25)
      m.x.should eq 5
      m.y.should eq 10
      m.elapsed.should eq Duration.new(0)
    end
  end
end

describe "State" do
  describe "serialization" do
    it "can be converted to JSON" do
      s = SomeModel::State.new(c: true)
      s.to_json.should eq("{\"a\":42,\"b\":\"foo\",\"c\":true}")

      s = Point3d::State.new(x: 42, y: 23, z: 76)
      s.to_json.should eq("{\"x\":42,\"y\":23,\"z\":76}")
    end
  end

  describe "deserialization" do
    it "can be initialized from JSON" do
      io = IO::Memory.new("{\"a\":13,\"b\":\"bar\",\"c\":true}")
      state = SomeModel::State.new(JSON::PullParser.new(io))

      state.a.should eq 13
      state.b.should eq "bar"
      state.c.should eq true

      io = IO::Memory.new("{\"x\":42,\"y\":23,\"z\":76}")
      state = Point3d::State.new(JSON::PullParser.new(io))
      state.should eq(Point3d::State.new(x: 42, y: 23, z: 76))
    end
  end
end
