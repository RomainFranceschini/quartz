require "./spec_helper"

describe DEVS::List do

  it "returns right size" do
    list = DEVS::List(Int32).new

    list.size.should eq(0)

    list.concat({1,2,3})
    list.size.should eq(3)

    list << 4 << 5 << 6
    list.size.should eq(6)

    list.pop
    list.pop
    list.size.should eq(4)


    list.pop
    list.pop
    list.pop
    list.pop
    list.size.should eq(0)
    list.pop
    list.size.should eq(0)
  end
end
