require "./spec_helper"
require "./coupling_helper"

private class ComplexCoupler < MyCoupler
  input :in
  output :out

  def initialize(name)
    super(name)
    a = MyCoupleable.new("a")
    b = MyCoupleable.new("b")
    c = MyCoupleable.new("c")
    self << a << b << c

    d = MyCoupleable.new("d")
    cm1 = MyCoupler.new("cm1")
    cm1a = MyCoupleable.new("a")
    cm1 << cm1a
    cm1.attach(cm1a.add_output_port(:outup), cm1.add_output_port(:outcm1a))
    self << cm1 << d

    e = MyCoupleable.new("e")
    cm2 = MyCoupler.new("cm2")
    cm2b = MyCoupleable.new("b")
    cm2 << cm2b
    cm2.attach(cm2.add_input_port(:incm2b), cm2b.add_input_port(:inup))
    self << cm2 << e

    # IC
    attach(a.add_output_port(:outa), b.add_input_port(:inb))
    attach(b.add_output_port(:outb), c.add_input_port(:inc))

    # EOC to in
    attach(cm1.output_port(:outcm1a), d.add_input_port(:incm1))
    # out to EIC
    attach(e.add_output_port(:outcm2), cm2.input_port(:incm2b))
    # EOC to EIC
    attach(cm1.output_port(:outcm1a), cm2.input_port(:incm2b))
  end
end

describe "Coupler" do
  describe "component handling" do
    describe "[]" do
      it "gets nilable" do
        MyCoupler.new("c")["component"]?.should be_nil
      end

      it "raises if component doesn't exist" do
        expect_raises NoSuchChildError, "no child named" do
          MyCoupler.new("c")["component"]
        end
      end
    end
  end

  describe "find_direct_couplings" do
    it "yields existing internal couplings" do
      model = ComplexCoupler.new("root")
      n = 0
      model.find_direct_couplings do |src, dst|
        if src.host == model["a"]
          n += 1
          src.name.should eq :outa
          dst.host.should eq model["b"]
          dst.name.should eq :inb
        elsif src.host == model["b"]
          n += 1
          src.name.should eq :outb
          dst.host.should eq model["c"]
          dst.name.should eq :inc
        end
      end
      n.should eq 2
    end

    it "yields depth source to simple destination" do
      model = ComplexCoupler.new("root")
      n = 0
      model.find_direct_couplings do |src, dst|
        if src.host == model["cm1"].as(Coupler)["a"] && dst.name == :incm1
          src.name.should eq :outup
          dst.host.should eq model["d"]
          n += 1
        end
      end
      n.should eq 1
    end

    it "yields depth destination from simple source" do
      model = ComplexCoupler.new("root")
      n = 0
      model.find_direct_couplings do |src, dst|
        if src.host == model["e"]
          src.name.should eq :outcm2
          dst.name.should eq :inup
          dst.host.should eq model["cm2"].as(Coupler)["b"]
          n += 1
        end
      end
      n.should eq 1
    end

    it "yields depth source to depth destination" do
      model = ComplexCoupler.new("root")
      n = 0
      model.find_direct_couplings do |src, dst|
        if src.name == :outup && dst.name == :inup
          src.host.should eq model["cm1"].as(Coupler)["a"]
          dst.host.should eq model["cm2"].as(Coupler)["b"]
          n += 1
        end
      end
      n.should eq 1
    end
  end

  describe "coupling" do
    describe "attach" do
      it "raises when coupling two ports of same component" do
        coupler = MyCoupler.new("c")
        a = MyCoupleable.new("a")
        coupler.add_child a
        ip = a.add_input_port("in")
        op = a.add_output_port("out")

        expect_raises FeedbackLoopError do
          coupler.attach(op, to: ip)
        end
      end

      it "raises if wrong hosts" do
        coupler1 = MyCoupler.new("c1")
        coupler2 = MyCoupler.new("c2")
        a = MyCoupleable.new "a"
        b = MyCoupleable.new "b"
        coupler1.add_child a
        coupler2.add_child b
        aop = b.add_output_port("out")
        bip = a.add_input_port("in")

        expect_raises InvalidPortHostError do
          coupler1.attach(aop, to: bip)
        end

        expect_raises InvalidPortHostError do
          coupler2.attach(aop, to: bip)
        end

        c1in = coupler1.add_input_port("c1in")
        c1out = coupler1.add_output_port("c1in")

        c2in = coupler2.add_input_port("c2in")
        c2out = coupler2.add_output_port("c2in")

        expect_raises InvalidPortHostError do
          coupler1.attach(c1in, to: c2in)
        end

        expect_raises InvalidPortHostError do
          coupler2.attach(c1out, to: c2in)
        end
      end
    end

    describe "detach" do
      coupler = MyCoupler.new("c")
      a = MyCoupleable.new("a")
      b = MyCoupleable.new("b")
      coupler << a << b

      aip = a.add_input_port("in")
      bop = b.add_output_port("out")
      it "detaches IC" do
        coupler.attach(bop, to: aip)
        coupler.detach(bop, from: aip).should be_true
      end

      myip = coupler.add_input_port("myin")
      it "detaches EIC" do
        coupler.attach(myip, to: aip)
        coupler.detach(myip, from: aip).should be_true
      end

      myop = coupler.add_output_port("myout")
      it "detaches EOC" do
        coupler.attach(bop, to: myop)
        coupler.detach(bop, from: myop).should be_true
      end

      it "is falsey when coupling doesn't exist" do
        coupler.detach(myop, from: bop).should be_false
        coupler.detach(bop, from: myip).should be_false

        coupler.attach(bop, to: a.add_input_port("in2"))
        coupler.detach(bop, from: aip).should be_false
      end
    end
  end
end
