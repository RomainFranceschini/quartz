require "./spec_helper"
require "./coupling_helper"

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
