require "./spec_helper"
require "big"

describe "VTime" do
  describe "comparison" do
    it "does with primitive types" do
      (VTime.new(0.0) == VTime.new(0.0)).should be_true
      (VTime.new(1.0) > VTime.new(0.0)).should be_true
      (VTime.new(1.0) < VTime.new(0.0)).should be_false
    end

    it "does with arbitrary precision types" do
      (VTime.new(BigFloat.new("0.99")) == VTime.new(BigFloat.new("0.99"))).should be_true
      (VTime.new(BigFloat.new("0.99")) > VTime.new(BigInt.new("12"))).should be_false
      (VTime.new(BigFloat.new("0.99")) < VTime.new(BigInt.new("12"))).should be_true
    end
  end

  it "does addition" do
    (VTime.new(1) + VTime.new(1)).should eq(VTime.new(2))
  end

  it "does substraction" do
    (VTime.new(2) - VTime.new(1)).should eq(VTime.new(1))
  end

  it "does division" do
    (VTime.new(10) / VTime.new(2)).should eq(VTime.new(5))
  end

  it "does multiplication" do
    (VTime.new(2) * VTime.new(2)).should eq(VTime.new(4))
  end

  it "does -" do
    (-VTime.new(2)).should eq(VTime.new(-2))
  end
end
