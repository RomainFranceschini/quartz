require "./spec_helper"
require "big"

describe "VTime" do
  describe "comparison" do
    it "does with primitive types" do
      (VirtualTime.new(0.0) == VirtualTime.new(0.0)).should be_true
      (VirtualTime.new(1.0) > VirtualTime.new(0.0)).should be_true
      (VirtualTime.new(1.0) < VirtualTime.new(0.0)).should be_false
    end

    it "does with arbitrary precision types" do
      (VirtualTime.new(BigFloat.new("0.99")) == VirtualTime.new(BigFloat.new("0.99"))).should be_true
      (VirtualTime.new(BigFloat.new("0.99")) > VirtualTime.new(BigInt.new("12"))).should be_false
      (VirtualTime.new(BigFloat.new("0.99")) < VirtualTime.new(BigInt.new("12"))).should be_true
    end
  end

  describe "arithmetics" do
    it "does addition" do
      (VirtualTime.new(1) + VirtualTime.new(1)).should eq(VirtualTime.new(2))
      (VirtualTime.new(10.0) + VirtualTime.new(12i64)).should eq VirtualTime.new(22)
    end

    it "does substraction" do
      (VirtualTime.new(2) - VirtualTime.new(1)).should eq(VirtualTime.new(1))
      (VirtualTime.new(10.0) - VirtualTime.new(1.0f32)).should eq VirtualTime.new(9)
    end

    # it "does division" do
    #   (VirtualTime(Int32).new(10) / VirtualTime(Int32).new(2)).should eq(VirtualTime(Int32).new(5))
    # end

    it "does multiplication" do
      (VirtualTime.new(2) * VirtualTime.new(2)).should eq(VirtualTime.new(4))
      (VirtualTime.new(4.0) * VirtualTime.new(2)).should eq(VirtualTime.new(8.0))
    end

    it "does -" do
      (-VirtualTime.new(2)).should eq(VirtualTime.new(-2))
    end
  end

  describe "infinity" do
    it "has specific infinity value" do
      VirtualTime.infinity.should eq(VirtualTime::Infinity.positive)
    end

    it "has negative infinity" do
      (-VirtualTime.infinity).should eq(VirtualTime::Infinity.negative)
    end

    it "is equal to IEE-754 infinity values" do
      (VirtualTime.infinity).should eq(Float32::INFINITY)
      (VirtualTime.infinity).should eq(Float64::INFINITY)
      (-VirtualTime.infinity).should eq(-Float32::INFINITY)
      (-VirtualTime.infinity).should eq(-Float64::INFINITY)
    end

    it "support comparison" do
      (VirtualTime::Infinity.new > Int64::MAX).should be_true
      (-VirtualTime::Infinity.new < Int64::MIN).should be_true

      (VirtualTime.infinity > VirtualTime.new(Int64::MAX)).should be_true
      (-VirtualTime.infinity < VirtualTime.new(Int64::MIN)).should be_true
      (VirtualTime.infinity < VirtualTime.zero).should be_false
      (VirtualTime.infinity > VirtualTime.zero).should be_true
    end

    it "support arithmetic operators" do
      (VirtualTime::Infinity.new + 1).should eq(VirtualTime::Infinity.new)
      (VirtualTime::Infinity.new - 1.0).should eq(VirtualTime::Infinity.new)
      (VirtualTime::Infinity.new * 2).should eq(VirtualTime::Infinity.new)
      (VirtualTime::Infinity.new / 1i16).should eq(VirtualTime::Infinity.new)

      (VirtualTime::Infinity.new + -4).should eq(VirtualTime::Infinity.new)
      (VirtualTime::Infinity.new - -4).should eq(VirtualTime::Infinity.new)
      (VirtualTime::Infinity.new * -2).should eq(-VirtualTime::Infinity.new)
      (VirtualTime::Infinity.new / -2).should eq(-VirtualTime::Infinity.new)

      (-VirtualTime::Infinity.new + 1).should eq(-VirtualTime::Infinity.new)
      (-VirtualTime::Infinity.new - 1.0).should eq(-VirtualTime::Infinity.new)
      (-VirtualTime::Infinity.new * 2).should eq(-VirtualTime::Infinity.new)
      (-VirtualTime::Infinity.new / 4i16).should eq(-VirtualTime::Infinity.new)

      (-VirtualTime::Infinity.new + -4).should eq(-VirtualTime::Infinity.new)
      (-VirtualTime::Infinity.new - -4).should eq(-VirtualTime::Infinity.new)
      (-VirtualTime::Infinity.new * -2).should eq(VirtualTime::Infinity.new)
      (-VirtualTime::Infinity.new / -2).should eq(VirtualTime::Infinity.new)

      (VirtualTime::Infinity.new + VirtualTime::Zero.new).should eq(VirtualTime::Infinity.new)
    end

    it "can be the rhs of a number operation" do
      (1.0f32 + VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
      (2 - VirtualTime::Infinity.new).should eq(-VirtualTime::Infinity.new)
      (4 * VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
      (10 / VirtualTime::Infinity.new).should eq(0)

      (-1.0 + VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
      (-2 - VirtualTime::Infinity.new).should eq(-VirtualTime::Infinity.new)
      (-5 * VirtualTime::Infinity.new).should eq(-VirtualTime::Infinity.new)
      (-3 / VirtualTime::Infinity.new).should eq(0)

      (1.0f32 + -VirtualTime::Infinity.new).should eq(-VirtualTime::Infinity.new)
      (2 - -VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
      (4 * -VirtualTime::Infinity.new).should eq(-VirtualTime::Infinity.new)
      (4 / -VirtualTime::Infinity.new).should eq(0)

      (-1.0f32 + -VirtualTime::Infinity.new).should eq(-VirtualTime::Infinity.new)
      (-2 - -VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
      (-4 * -VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
      (-4 / -VirtualTime::Infinity.new).should eq(0)

      (VirtualTime::Zero.new + VirtualTime::Infinity.new).should eq(VirtualTime::Infinity.new)
    end
  end

  describe "zero" do
    it "has specific zero value" do
      VirtualTime.zero.should eq(VirtualTime(Float64).new(0.0))
    end

    it "is equal to primitive number zero values" do
      VirtualTime.zero.should eq(Int32.zero)
      VirtualTime.zero.should eq(Int64.zero)
      VirtualTime.zero.should eq(Int16.zero)
      VirtualTime.zero.should eq(Int8.zero)
      VirtualTime.zero.should eq(UInt32.zero)
      VirtualTime.zero.should eq(UInt64.zero)
      VirtualTime.zero.should eq(UInt16.zero)
      VirtualTime.zero.should eq(UInt8.zero)
      VirtualTime.zero.should eq(Float32.zero)
      VirtualTime.zero.should eq(Float64.zero)
    end

    it "support comparison" do
      (VirtualTime.zero < 1).should be_true
      (VirtualTime.zero > 1.0).should be_false
      (VirtualTime.zero < VirtualTime.infinity).should be_true
      (VirtualTime.zero > VirtualTime.infinity).should be_false
    end

    it "support arithmetic operators" do
      (VirtualTime::Zero.new + 1).should eq(1)
      (VirtualTime::Zero.new - 1).should eq(-1)
      (VirtualTime::Zero.new * 2).should eq(0)
      (VirtualTime::Zero.new / 10).should eq(0)
      (VirtualTime::Zero.new + -10).should eq(-10)
      (VirtualTime::Zero.new - -10).should eq(10)
    end

    it "can be the rhs of number operations" do
      (1 + VirtualTime::Zero.new).should eq(1)
      (1 - VirtualTime::Zero.new).should eq(1)
      (-1 + VirtualTime::Zero.new).should eq(-1)
      (-1 - VirtualTime::Zero.new).should eq(-1)
      (2 * VirtualTime::Zero.new).should eq(0)
      expect_raises(DivisionByZero) do
        (2 / VirtualTime::Zero.new)
      end
      (2.0 / VirtualTime::Zero.new).should eq(Float64::INFINITY)
      (2.0 / VirtualTime::Zero.new).should eq(VirtualTime::Infinity.new)
    end
  end
end
