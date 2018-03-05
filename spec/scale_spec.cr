require "./spec_helper"

describe "Scale" do
  it "scale division yields a power of factor constant" do
    (Scale::TERA / Scale::MEGA).should eq(Scale::FACTOR ** 2)
    (Scale::MILLI / Scale::PICO).should eq(1000000000)
    (Scale::PICO / Scale::MILLI).should eq(0.000000001)
    (Scale::TERA / Scale::TERA).should eq(1)
  end

  it "does inverse" do
    (-Scale::KILO).should eq(Scale::MILLI)
  end

  it "does exponent addition" do
    (Scale::NANO + 4).should eq(Scale::KILO)
  end

  it "does exponent substraction" do
    (Scale::MICRO - 3).should eq(Scale::FEMTO)
  end

  it "computes distance between precisions" do
    (Scale::TERA - Scale::MEGA).should eq(2)
    (Scale.new(-4) - Scale.new(-3)).should eq(1)
    (Scale.new(-1) - Scale.new(1)).should eq(2)
    (Scale.new(1) - Scale.new(-1)).should eq(2)
    (Scale.new(8) - Scale.new(-8)).should eq(16)
  end

  it "can be added with a number" do
    (1 + Scale::MILLI).should eq(Scale::BASE)
  end
end
