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

describe "AtomicModel" do
  describe "post" do
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

  describe "fetch_output!" do
    it "calls #output" do
      m = FetchOutputTest.new
      m.fetch_output![m.output_port("out")].should eq("a value")
      m.calls.should eq(1)
    end
  end

end
