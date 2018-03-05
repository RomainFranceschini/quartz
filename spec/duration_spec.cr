require "./spec_helper"

describe "Duration" do
  describe "with unfixed precision" do
    describe "may refine scale" do
      it "for addition" do
        (Duration.new(4) + Duration.new(10, Scale::MILLI)).equals?(Duration.new(4010, Scale::MILLI)).should be_true
        (Duration.new(10, Scale::MILLI) + Duration.new(4)).equals?(Duration.new(4010, Scale::MILLI)).should be_true
        (Duration.new(10) + Duration.new(10)).equals?(Duration.new(20)).should be_true

        (Duration.new(3) + Duration.new(475, Scale::MILLI)).equals?(Duration.new(3475, Scale::MILLI)).should be_true
        (Duration.new(1, Scale::KILO) + Duration.new(1, Scale::MICRO)).equals?(Duration.new(1000000001, Scale::MICRO))
      end

      it "for substraction" do
        (Duration.new(4) - Duration.new(10, Scale::MILLI)).equals?(Duration.new(3990, Scale::MILLI)).should be_true
        (Duration.new(10, Scale::MILLI) - Duration.new(4)).equals?(Duration.new(-3990, Scale::MILLI)).should be_true
        (Duration.new(10) - Duration.new(5)).equals?(Duration.new(5)).should be_true

        (Duration.new(500, Scale.new(-4)) - Duration.new(1, Scale.new(-3))).equals?(Duration.new(-500, Scale.new(-4))).should be_true
      end

      it "for division" do
        (Duration.new(100) / 5).equals?(Duration.new(20)).should be_true
        (Duration.new(4010, Scale::MILLI) / 4).equals?(Duration.new(1002500, Scale::MICRO)).should be_true

        # TODO fix: first returns infinity, but shouldn't overflow
        (Duration.new(1000, Scale::MILLI) / 3).should eq(Duration.new(333333333333333, Scale.new(-5)))
      end

      it "for multiplication" do
        (Duration.new(100) * 0.2).equals?(Duration.new(20)).should be_true
        (5 * Duration.new(100)).equals?(Duration.new(500)).should be_true
        (0.2 * Duration.new(100)).equals?(Duration.new(20)).should be_true

        (Duration.new(10) * 0.001).equals?(Duration.new(10, Scale::MILLI)).should be_true

        ((1.0/3) * Duration.new(1)).should eq(Duration.new(333333333333333, Scale.new(-5)))
        ((1.0/3) * Duration.new(1000, Scale::MILLI)).should eq(Duration.new(333333333333333, Scale.new(-5)))
      end
    end

    describe "may coarse scale avoiding overflow" do
      it "for multiplication" do
        (1000000 * Duration.new(1000000000, Scale.new(-5))).equals?(Duration.new(1000000000000, Scale.new(-4))).should be_true
        (-1000000 * Duration.new(1000000000, Scale.new(-5))).equals?(Duration.new(-1000000000000, Scale.new(-4))).should be_true
        (1000000000 * Duration.new(1000000000, Scale.new(-5))).equals?(Duration.new(1000000000000, Scale.new(-3))).should be_true
        (-1000000000 * Duration.new(1000000000, Scale.new(-5))).equals?(Duration.new(-1000000000000, Scale.new(-3))).should be_true
      end

      it "for addition" do
        (Duration.new(999999999999999, Scale.new(2)) + Duration.new(1, Scale.new(2))).equals?(Duration.new(1000000000000, Scale.new(3))).should be_true
        (Duration.new(-999999999999999, Scale.new(2)) + Duration.new(-1, Scale.new(2))).equals?(Duration.new(-1000000000000, Scale.new(3))).should be_true
      end

      it "for substraction" do
        (Duration.new(-999999999999999, Scale.new(2)) - Duration.new(1, Scale.new(2))).equals?(Duration.new(-1000000000000, Scale.new(3))).should be_true
      end
    end
  end

  it "division with another duration is a floating-point operation" do
    (Duration.new(1, Scale::MILLI) / Duration.new(1, Scale::BASE)).should eq(0.001)
  end

  describe "with fixed precision" do
    it "operations fails on different scales" do
      expect_raises(Exception, "Duration addition operation requires same precision level between operands.") do
        Duration.new(2, fixed: true) + Duration.new(3, Scale::MILLI, fixed: true)
      end

      expect_raises(Exception, "Duration substraction operation requires same precision level between operands.") do
        Duration.new(2, fixed: true) - Duration.new(3, Scale::MILLI, fixed: true)
      end
    end

    it "does addition on same scales" do
      (Duration.new(2, fixed: true) + Duration.new(3)).equals?(Duration.new(5, Scale::BASE, true)).should be_true
    end

    it "does substraction on same scales" do
      (Duration.new(2, fixed: true) - Duration.new(3)).equals?(Duration.new(-1, Scale::BASE, true)).should be_true
    end

    it "does division with a scalar operand" do
      (Duration.new(100, fixed: true) / 5).equals?(Duration.new(20)).should be_true
      (Duration.new(100, fixed: true) / 8).equals?(Duration.new(13)).should be_true
      (Duration.new(4010, Scale::MILLI, true) / 4).equals?(Duration.new(1003, Scale::MILLI)).should be_true
    end

    it "does multiplication with a scalar operand" do
      (Duration.new(5, fixed: true)*100).equals?(Duration.new(500))
      (0.2 * Duration.new(100, fixed: true)).equals?(Duration.new(20))
      (Duration.new(100, fixed: true) * 0.2).equals?(Duration.new(20))

      ((1.0/3) * Duration.new(1, fixed: true)).equals?(Duration.new(0))
      ((1.0/3) * Duration.new(1000, Scale::MILLI, fixed: true)).equals?(Duration.new(333, Scale::MILLI))
      ((1.0/3) * Duration.new(1000000, Scale::MICRO, fixed: true)).equals?(Duration.new(333333, Scale::MICRO))
    end

    describe "propagates" do
      it "for addition" do
        (Duration.new(2, fixed: true) + Duration.new(3)).fixed?.should be_true
        (Duration.new(2) + Duration.new(3, fixed: true)).fixed?.should be_true

        (Duration.new(2, Scale::MILLI, fixed: true) + Duration.new(1)).equals?(Duration.new(1002, Scale::MILLI, true)).should be_true
        (Duration.new(2) + Duration.new(1, Scale::MEGA, true)).equals?(Duration.new(1, Scale::MEGA, true)).should be_true
      end

      it "for substraction" do
        (Duration.new(2, fixed: true) - Duration.new(3)).fixed?.should be_true
        (Duration.new(2) - Duration.new(3, fixed: true)).fixed?.should be_true

        (Duration.new(2, Scale::MILLI, fixed: true) - Duration.new(1)).equals?(Duration.new(-998, Scale::MILLI, true)).should be_true
        (Duration.new(2) - Duration.new(1, Scale::MEGA, true)).equals?(Duration.new(-1, Scale::MEGA, true)).should be_true
      end

      it "for multiplication" do
        (Duration.new(10, fixed: true) * 0.01).fixed?.should be_true
        (Duration.new(10, fixed: true) * 0.01).equals?(Duration.new(0)).should be_true
      end

      it "for division" do
        (Duration.new(10, fixed: true) / 100).fixed?.should be_true
        (Duration.new(10, fixed: true) / 100).equals?(Duration.new(0)).should be_true
      end

      it "for inverse" do
        (-Duration.new(10, fixed: true)).fixed?.should be_true
      end
    end
  end

  it "can be infinite" do
    Duration.new(0).finite?.should be_true
    Duration.new(Int64::MAX).infinite?.should be_true
    Duration.new(-Int64::MAX).infinite?.should be_true

    (Duration.new(999999999999999, Scale::MEGA, true) + Duration.new(2, Scale::MEGA)).infinite?.should be_true
    (-1000000 * Duration.new(1000000000, Scale::FEMTO, true)).infinite?.should be_true
  end

  it "can be rescaled" do
    Duration.new(1).rescale(Scale::MILLI).equals?(Duration.new(1000, Scale::MILLI, false)).should be_true
    Duration.new(1, fixed: true).rescale(Scale::MILLI).equals?(Duration.new(1000, Scale::MILLI, true)).should be_true
    Duration.new(1).fixed_at(Scale::MILLI).equals?(Duration.new(1000, Scale::MILLI, true)).should be_true
    Duration.new(1).fixed_at(Scale::KILO).equals?(Duration.new(0, Scale::KILO, true)).should be_true

    Duration.new(1).rescale(Scale::FEMTO).infinite?.should be_true
    Duration.new(1).fixed_at(Scale::FEMTO).infinite?.should be_true

    Duration.new(1).rescale(Scale::FEMTO).should eq(Duration::INFINITY)
    Duration.new(1).fixed_at(Scale::FEMTO).should eq(Duration::INFINITY)
  end

  it "can be compared" do
    (Duration.new(1) <=> Duration.new(1)).should eq(0)
    (Duration.new(1) <=> Duration.new(1000, Scale::MILLI)).should eq(0)
    (Duration.new(1) <=> Duration.new(1000000, Scale::MICRO)).should eq(0)
    (Duration.new(1000, Scale::MILLI) <=> Duration.new(1000000, Scale::MICRO)).should eq(0)

    (Duration.new(2) > Duration.new(1000, Scale::MILLI)).should be_true
    (Duration.new(2) < Duration.new(3000, Scale::MILLI)).should be_true
    (Duration.new(-8, Scale::PICO) < Duration.new(-7, Scale::PICO)).should be_true

    (Duration.new(999999999999999, Scale::MEGA, true) + Duration.new(2, Scale::MEGA)).should eq(Duration::INFINITY)
    Duration.new(-Int64::MAX).should eq(-Duration::INFINITY)

    (Duration.new(500, Scale::MILLI) + Duration.new(500, Scale::MILLI)).should eq(Duration.new(1))
    (Duration.new(500, Scale::MILLI) + Duration.new(500, Scale::MILLI)).equals?(Duration.new(1)).should be_false
    (Duration.new(500, Scale::MILLI) + Duration.new(500, Scale::MILLI)).equals?(Duration.new(1000, Scale::MILLI)).should be_true
  end
end
