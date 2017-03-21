require "./spec_helper"
require "./coupling_helper"

describe "Coupleable" do
  describe "macros" do
    it "should define specified input ports for each instance" do
      Foo.new(:foo1).input_ports.keys.should eq([:iport1])
      Foo.new(:foo2).input_ports.values.map(&.name).should eq([:iport1])
    end

    it "should define specified output ports for each instance" do
      Foo.new(:foo1).output_ports.keys.should eq([:oport1, :oport2, :oport3])
      Foo.new(:foo2).output_ports.values.map(&.name).should eq([:oport1, :oport2, :oport3])
    end

    it "should inherit input ports defined in parent classes" do
      Bar.new(:bar1).input_ports.keys.should eq([:iport1, :iport2])
      Bar.new(:bar2).input_ports.values.map(&.name).should eq([:iport1, :iport2])
    end

    it "should inherit output ports defined in parent classes" do
      Bar.new(:bar1).output_ports.keys.should eq([:oport1, :oport2, :oport3])
      Bar.new(:bar2).output_ports.values.map(&.name).should eq([:oport1, :oport2, :oport3])
    end

    it "also adds ports defined at runtime" do
      f = Foo.new(:foo1)
      f.add_input_port(:newin)
      f.input_ports.keys.should eq([:iport1, :newin])
      f.input_ports.values.map(&.name).should eq([:iport1, :newin])

      b = Bar.new(:bar1)
      b.add_output_port(:newout)
      b.output_ports.keys.should eq([:oport1, :oport2, :oport3, :newout])
      b.output_ports.values.map(&.name).should eq([:oport1, :oport2, :oport3, :newout])
    end
  end

  describe "port creation" do
    it "adds ports" do
      c = MyCoupleable.new("a")
      ip = InputPort.new(c, "input")
      op = OutputPort.new(c, :output)
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
      ip = InputPort.new(c, "input")
      op = OutputPort.new(c, :output)
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
      ip = c.find_or_create_input_port_if_necessary("in")
      op = c.find_or_create_output_port_if_necessary("out")

      ip.should be_a(InputPort)
      op.should be_a(OutputPort)
      ip.name.should eq("in")
      op.name.should eq("out")

      ip2 = c.add_input_port("in2")
      op2 = c.add_output_port("out2")

      c.find_or_create_input_port_if_necessary("in2").should eq(ip2)
      c.find_or_create_output_port_if_necessary("out2").should eq(op2)
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
