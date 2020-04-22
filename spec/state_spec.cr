require "./spec_helper"

private struct SomeModel
  include Stateful

  state a : Int32 = 42,
    b : String = "foo",
    c : Bool = false
end

private struct Empty
  include Stateful
end

private struct Nilable
  include Stateful

  state str : String? = nil
end

private struct UnionStateVar
  include Stateful

  state str_or_int : String | Int32 = 0
end

private struct AfterInitialize
  include Stateful

  state x : Int32 = 0, y : Int32 = 0
end

abstract struct AfterInitializeParent
  include Stateful

  @name : String

  def initialize(@name)
  end
end

private struct InitializeChild < AfterInitializeParent
  state test : Int32 do
    @test = 42
  end
end

private struct NoInitializeChild < AfterInitializeParent
  state test : Int32 = 42
end

private class Point2d
  # include JSON::Serializable
  include Stateful

  state x : Int32 = 0, y : Int32 = 0
end

class Point3d < Point2d
  state z : Int32 = 0

  def xyz
    {x, y, z}
  end
end

private struct DependentStateVars
  include Stateful

  state x : Int32 = 0, y : Int32 = 0, pos : Tuple(Int32, Int32) do
    @pos = Tuple.new(x, y)
  end
end

private abstract struct BaseSigmaModel
  include Stateful
  state sigma : Duration = Duration::INFINITY
end

private struct MySigmaModel < BaseSigmaModel
  state sigma = Duration.new(85, Scale::MILLI)
end

describe "Stateful" do
  describe "getters" do
    it "are defined for each state variable" do
      s = SomeModel.new
      s.responds_to?(:a).should be_true
      s.a.should eq 42

      s.responds_to?(:b).should be_true
      s.b.should eq "foo"

      s.responds_to?(:c).should be_true
    end
  end

  describe "State type" do
    it "defines dedicated state type" do
      s = SomeModel.new
      s.state.should be_a(SomeModel::State)
      s.state.is_a?(Quartz::State).should be_true
    end

    describe "#initialize" do
      it "accepts values as named arguments" do
        s = SomeModel::State.new(c: true, a: 1000, b: "quz")
        s.a.should eq 1000
        s.b.should eq "quz"
        s.c.should be_true
      end

      it "uses default values for omitted values" do
        s = SomeModel::State.new(c: true)
        s.a.should eq 42
        s.b.should eq "foo"
        s.c.should eq true
      end

      it "uses provided block to expand constructors" do
        s = AfterInitialize::State.new
        s.x.should eq 0
        s.y.should eq 0
      end

      it "given values overrides provided block" do
        s = AfterInitialize::State.new(x: 1, y: 1)
        s.x.should eq 1
        s.y.should eq 1
      end
    end

    it "has getters" do
      s = SomeModel::State.new
      s.responds_to?(:a).should be_true
      s.responds_to?(:b).should be_true
      s.responds_to?(:c).should be_true

      s.a.should eq 42
      s.b.should eq "foo"
      s.c.should eq false
    end

    it "to_named_tuple" do
      s = SomeModel::State.new
      s.to_named_tuple.should eq({a: 42, b: "foo", c: false})
    end

    it "to_hash" do
      s = SomeModel::State.new
      s.to_hash.should eq({:a => 42, :b => "foo", :c => false})
    end

    # describe "serialization" do
    #   it "can be converted to JSON" do
    #     s = SomeModel::State.new(c: true)
    #     s.to_json.should eq("{\"a\":42,\"b\":\"foo\",\"c\":true}")

    #     s = Point3d::State.new(x: 42, y: 23, z: 76)
    #     s.to_json.should eq("{\"x\":42,\"y\":23,\"z\":76}")
    #   end
    # end

    # describe "deserialization" do
    #   it "can be initialized from JSON" do
    #     io = IO::Memory.new("{\"a\":13,\"b\":\"bar\",\"c\":true}")
    #     state = SomeModel::State.new(JSON::PullParser.new(io))

    #     state.a.should eq 13
    #     state.b.should eq "bar"
    #     state.c.should eq true

    #     io = IO::Memory.new("{\"x\":42,\"y\":23,\"z\":76}")
    #     state = Point3d::State.new(JSON::PullParser.new(io))
    #     state.should eq(Point3d::State.new(x: 42, y: 23, z: 76))

    #     io = IO::Memory.new("{\"state\":{\"x\":42,\"y\":23,\"z\":76}}")
    #     model = Point3d.new(JSON::PullParser.new(io))
    #     model.state.should eq(Point3d::State.new(x: 42, y: 23, z: 76))
    #   end
    # end
  end

  context "inheritance" do
    it do
      m = Point2d.new
      m.x.should eq 0
      m.y.should eq 0

      s = Point2d::State.new(x: 1, y: 1)
      s.x.should eq 1
      s.y.should eq 1
    end

    it "subclasses inherits state of parents" do
      m = Point3d.new
      m.x.should eq 0
      m.y.should eq 0
      m.z.should eq 0
      m.xyz.should eq({0, 0, 0})

      s = Point3d::State.new(x: 1, y: 1, z: 1)
      s.x.should eq 1
      s.y.should eq 1
      s.z.should eq 1
    end

    it "parent constructors are still available when `state` is used in subclasses" do
      m = InitializeChild.new("bar")
      m.@name.should eq "bar"
      m.test.should eq 42
    end

    it "it inherits constructors of parents" do
      m = NoInitializeChild.new("foo")
      m.@name.should eq "foo"
      m.test.should eq 42
    end

    context "with multiple state expressions" do
      it "existing variables can be overriden" do
        s = MySigmaModel.new
        s.responds_to?(:sigma).should be_true
        s.sigma.should eq(Duration.new(85, Scale::MILLI))
      end
    end
  end

  context "expand" do
    it "works with empty type" do
      empty = Empty.new
    end

    it "works with union types" do
      m = UnionStateVar.new
      m.str_or_int.should eq 0

      s = UnionStateVar::State.new(str_or_int: 12)
      s.str_or_int.should eq 12

      s = UnionStateVar::State.new(str_or_int: "foo")
      s.str_or_int.should eq "foo"
    end

    it "works wkth nilable types" do
      m = Nilable.new
      m.str.should be_nil

      s = Nilable::State.new(str: "foo")
      s.str.should eq "foo"

      s = Nilable::State.new(str: nil)
      s.str.should eq nil
    end

    it "defines a constructor in included class if no one is defined" do
      m = AfterInitialize.new
      m.x.should eq 0
      m.y.should eq 0
    end
  end

  context "with default values" do
    it "initialize state accordingly" do
      s = SomeModel.new

      s.a.should eq 42
      s.b.should eq "foo"
      s.c.should eq false

      s.a.should eq 42
      s.b.should eq "foo"

      s.state.tap do |state|
        state.a.should eq 42
        state.b.should eq "foo"
        state.c.should eq false
      end
    end
  end

  context "with dependent state variables" do
    it "allows initialization using a block" do
      s = DependentStateVars.new
      s.pos.should eq({0, 0})
    end
  end

  context "without default values" do
    it "state vars can be initialized through state" do
      s = AfterInitialize.new
      s.x.should eq 0
      s.y.should eq 0
    end
  end
end
