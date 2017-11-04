require "./spec_helper"

describe Quartz::Any do
  describe "casts" do
    it "gets nil" do
      Any.new(nil).as_nil.should be_nil
    end

    it "gets bool" do
      Any.new(true).as_bool.should be_true
      Any.new(false).as_bool.should be_false
      Any.new(true).as_bool?.should be_true
      Any.new(false).as_bool?.should be_false
      Any.new(2).as_bool?.should be_nil
    end

    it "gets int" do
      Any.new(123).as_i.should eq(123)
      Any.new(123456789123456).as_i64.should eq(123456789123456)
      Any.new(123).as_i?.should eq(123)
      Any.new(123456789123456).as_i64?.should eq(123456789123456)
      Any.new(true).as_i?.should be_nil
      Any.new(true).as_i64?.should be_nil
    end

    it "gets float" do
      Any.new(123.45).as_f.should eq(123.45)
      Any.new(123.45_f32).as_f32.should eq(123.45_f32)
      Any.new(123.45).as_f?.should eq(123.45)
      Any.new(123.45_f32).as_f32?.should eq(123.45_f32)
      Any.new(true).as_f?.should be_nil
      Any.new(true).as_f32?.should be_nil
    end

    it "gets string" do
      Any.new("hello").as_s.should eq("hello")
      Any.new("hello").as_s?.should eq("hello")
      Any.new(true).as_s?.should be_nil
    end
  end

  describe "#size" do
    it "of array" do
      Any.new([1, 2, 3].map { |x| Any.new(x) }).size.should eq(3)
    end

    it "of hash" do
      Any.hash.tap { |h| h["foo"] = "bar" }.size.should eq(1)
    end
  end

  describe "builders" do
    it ".hash" do
      Any.hash.should eq Any.new(Hash(Any, Any).new)
    end

    it ".array" do
      Any.array.should eq Any.new(Array(Any).new)
    end

    it ".build_hash" do
      Any.build_hash { |any|
        any["foo"] = "bar"
      }.should eq({"foo" => "bar"})
    end

    it ".build_array" do
      Any.build_array { |any|
        any << 1 << 2
      }.should eq([1, 2])
    end
  end

  it "#<< for underlying arrays" do
    obj = [] of Any
    obj << Any.new(1) << Any.new(2)
    Any.new(obj).should eq Any.array.tap { |a| a << 1 << 2 }
  end

  describe "#[]" do
    it "of array" do
      Any.array.tap { |a| a << 1 << 2 << 3 }[1].raw.should eq(2)
    end

    it "of hash" do
      Any.hash.tap { |h| h["foo"] = "bar" }["foo"].raw.should eq("bar")
    end
  end

  describe "#[]?" do
    it "of array" do
      Any.array.tap { |a| a << 1 << 2 << 3 }[1]?.not_nil!.raw.should eq(2)
      Any.array.tap { |a| a << 1 << 2 << 3 }[3]?.should be_nil
      Any.array.tap { |a| a << true << false }[1]?.should eq false
    end

    it "of hash" do
      Any.hash.tap { |h| h["foo"] = "bar" }["foo"]?.not_nil!.raw.should eq("bar")
      Any.hash.tap { |h| h["foo"] = "bar" }["fox"]?.should be_nil
      Any.hash.tap { |h| h["foo"] = false }["foo"]?.should eq false
    end
  end

  it "compares to other objects" do
    obj = Any.array.tap { |a| a << 1 << 2 }
    obj.should eq([1, 2])
    obj[0].should eq(1)
  end

  it "can compare with ===" do
    (1 === Any.new(1)).should be_truthy
  end

  it "exposes $~ when doing Regex#===" do
    (/o+/ === Any.new("foo")).should be_truthy
    $~[0].should eq("oo")
  end
end
