require "./spec_helper"

private struct SomeModel
  include AutoState

  state_var a : Int32 = 42
  state_var b : String = "foo"
  state_var c : Bool = false, visibility: :private
end

private struct Empty
  include AutoState
end

private struct Nilable
  include AutoState

  state_var str : String? = nil
end

private struct UnionStateVar
  include AutoState

  state_var str_or_int : String|Int32 = 0
end

private struct AfterInitialize
  include AutoState

  state_var x : Int32
  state_var y : Int32

  state_initialize do
    @x = 0
    @y = 0
  end
end

private struct BlockStateVars
  include AutoState

  state_var x : Int32 { 0 }
  state_var y : Int32 { 0 }
end

private class Point2d
  include AutoState

  state_var x : Int32 = 0
  state_var y : Int32 = 0
end

private class Point3d < Point2d
  state_var z : Int32 = 0

  def xyz
    { @x, @y, @z }
  end
end

private struct DependentStateVars
  include AutoState

  state_var x : Int32 = 0
  state_var y : Int32 = 0

  state_var pos : Tuple(Int32,Int32) { Tuple.new(x, y) }
end

private struct RedefineConstructor
  include AutoState

  @name : String

  state_var x : Int32 = 0
  state_var y : Int32 = 0

  def initialize(@name)
  end

  def initialize(@name, *, hello = 42, &block)
  end

  def initialize(@name, *splat, **dsplat, &block)
  end
end

describe "AutoState" do
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
    it "defines dedicated state struct type" do
      s = SomeModel.new
      s.state.should be_a(SomeModel::State)
      s.state.is_a?(Value).should be_true
    end

    describe "#initialize" do
      it "accepts values as named arguments" do
        s = SomeModel::State.new(c: true, a: 1000, b: "quz")
        s.@a.should eq 1000
        s.@b.should eq "quz"
        s.@c.should be_true
      end

      it "uses default values for omitted values" do
        s = SomeModel::State.new(c: true)
        s.@a.should eq 42
        s.@b.should eq "foo"
        s.@c.should eq true
      end

      it "uses `state_initialize` block to expand constructors" do
        s = AfterInitialize::State.new
        s.@x.should eq 0
        s.@y.should eq 0
      end

      it "given values overrides `state_initialize` block" do
        s = AfterInitialize::State.new(x: 1, y: 1)
        s.@x.should eq 1
        s.@y.should eq 1
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

    it "to_tuple" do
      s = SomeModel::State.new
      s.to_tuple.should eq({ 42, "foo", false })
    end

    it "to_named_tuple" do
      s = SomeModel::State.new
      s.to_named_tuple.should eq({ a: 42, b: "foo", c: false })
    end

    it "to_hash" do
      s = SomeModel::State.new
      s.to_hash.should eq({ :a => 42, :b => "foo", :c => false })
    end

    describe "serialization" do
      it "can be converted to JSON" do
        s = SomeModel::State.new(c: true)
        s.to_json.should eq("{\"a\":42,\"b\":\"foo\",\"c\":true}")
      end

      it "can be converted to msgpack" do
        s = SomeModel::State.new(c: true)
        s.to_msgpack.should eq Bytes[131, 161, 97, 42, 161, 98, 163, 102, 111, 111, 161, 99, 195]
      end
    end

    describe "deserialization" do
      it "can be initialized from JSON" do
        io = IO::Memory.new("{\"a\":42,\"b\":\"foo\",\"c\":true}")
        state = SomeModel::State.new(JSON::PullParser.new(io))

        state.a.should eq 42
        state.b.should eq "foo"
        state.c.should eq true
      end

      it "can be initialized from msgpack" do
        io = IO::Memory.new(Bytes[131, 161, 97, 42, 161, 98, 163, 102, 111, 111, 161, 99, 195])
        state = SomeModel::State.new(MessagePack::Unpacker.new(io))

        state.a.should eq 42
        state.b.should eq "foo"
        state.c.should eq true
      end
    end
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
      m.xyz.should eq({ 0, 0 ,0 })

      s = Point3d::State.new(x: 1, y: 1, z: 1)
      s.x.should eq 1
      s.y.should eq 1
      s.z.should eq 1
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

    it "redefines existing constructor in included class to include `state_initialize` block" do
      m = RedefineConstructor.new("foo1")
      m.@name.should eq "foo1"
      m.@x.should eq 0
      m.@y.should eq 0

      m2 = RedefineConstructor.new("foo2", hello: 1000) { nil }
      m2.@name.should eq "foo2"
      m2.@x.should eq 0
      m2.@y.should eq 0

      m3 = RedefineConstructor.new("foo3", 1, 2, 3, bar: 0) { nil }
      m3.@name.should eq "foo3"
      m3.@x.should eq 0
      m3.@y.should eq 0
    end
  end

  context "with default values" do
    it "initialize state accordingly" do
      s = SomeModel.new

      s.@a.should eq 42
      s.@b.should eq "foo"
      s.@c.should eq false

      s.a.should eq 42
      s.b.should eq "foo"

      s.state.tap do |state|
        state.a.should eq 42
        state.b.should eq "foo"
        state.c.should eq false
      end
    end
  end

  context "with default values as blocks" do
    it "initialize state accordingly" do
      s = BlockStateVars.new

      s.@x.should eq nil
      s.@y.should eq nil

      s.x.should eq 0
      s.y.should eq 0

      s.state.tap do |state|
        state.x.should eq 0
        state.y.should eq 0
      end
    end
  end

  context "with dependent state variables" do
    it "allows initialization using a block" do
      s = DependentStateVars.new
      s.@pos.should eq nil
      s.pos.should eq({0, 0})
    end
  end

  context "without default values" do
    it "state vars can be initialized through `state_initialize`" do
      s = AfterInitialize.new
      s.@x.should eq 0
      s.@y.should eq 0
    end
  end
end
