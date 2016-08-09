require "./spec_helper"
require "./coupling_helper"

describe "Coupleable" do
  describe "port creation" do
    it "adds ports" do
      c = MyCoupleable.new("a")
      ip = Port.new(c, IOMode::Input, "input")
      op = Port.new(c, IOMode::Output, :output)
      c.add_port(ip)
      c.add_port(op)

      c.input_port("input").should eq(ip)
      c.output_port(:output).should eq(op)
    end

    it "adds ports by name" do
      c = MyCoupleable.new("a")
      c.add_input_port("in").should be_a(Port)
      c.add_output_port("out").should be_a(Port)

      c.input_port("in").name.should eq("in")
      c.output_port("out").name.should eq("out")
    end
  end

  describe "port removal" do
    it "removes ports" do
      c = MyCoupleable.new("a")
      ip = Port.new(c, IOMode::Input, "input")
      op = Port.new(c, IOMode::Output, :output)
      c.add_port(ip)
      c.add_port(op)

      c.remove_port(ip).should eq(ip)
      c.remove_port(op).should eq(op)
    end

    it "removes ports by name" do
      c = MyCoupleable.new("a")
      ip = c.add_input_port("in")
      op = c.add_output_port("out")
      c.remove_input_port("in").should eq(ip)
      c.remove_output_port("out").should eq(op)
    end

    it "gets nilable" do
      MyCoupleable.new("a").remove_input_port("hello").should be_nil
      MyCoupleable.new("a").remove_output_port("hello").should be_nil
    end
  end

  describe "port retrieval" do
    it "raises on unknown port" do
      expect_raises(NoSuchPortError) do
        MyCoupleable.new("a").input_port("hello")
      end
      expect_raises(NoSuchPortError) do
        MyCoupleable.new("a").output_port("hello")
      end
    end

    it "gets nilable when given port doesn't exist" do
      MyCoupleable.new("a").input_port?("hello").should be_nil
      MyCoupleable.new("a").output_port?("hello").should be_nil
    end

    it "creates specified port if it doesn't exist" do
      c = MyCoupleable.new("a")
      ip = c.find_create("in", IOMode::Input)
      op = c.find_create("out", IOMode::Output)

      ip.should be_a(Port)
      op.should be_a(Port)
      ip.name.should eq("in")
      op.name.should eq("out")

      ip2 = c.add_input_port("in2")
      op2 = c.add_output_port("out2")

      c.find_create("in2", IOMode::Input).should eq(ip2)
      c.find_create("out2", IOMode::Output).should eq(op2)
    end
  end

  it "returns the list of port names" do
    c = MyCoupleable.new("a")
    c.add_input_port("in")
    c.add_input_port("in2")
    c.add_input_port("in3")

    c.add_output_port("out")
    c.add_output_port("out1")

    c.input_port_names.should eq ["in", "in2", "in3"]
    c.output_port_names.should eq ["out", "out1"]
  end

  it "returns the list of ports" do
    c = MyCoupleable.new("a")
    in1 = c.add_input_port("in")
    in2 = c.add_input_port("in2")
    in3 = c.add_input_port("in3")

    out1 = c.add_output_port("out")
    out2 = c.add_output_port("out1")

    c.input_port_list.should eq [in1, in2, in3]
    c.output_port_list.should eq [out1, out2]
  end
end
