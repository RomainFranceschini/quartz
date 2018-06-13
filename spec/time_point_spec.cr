require "./spec_helper"

describe "TimePoint" do
  describe "#initialize" do
    it "accepts any integer" do
      tp = TimePoint.new(5000388, Scale.new(3))
      tp.size.should eq(3)
      tp.precision.should eq(Scale.new(3))
      tp.@magnitude.should eq([388, 0, 5])
    end
  end

  describe "#to_i64" do
    it "restores the time point as an integer" do
      tp = TimePoint.new(5000388)
      tp.to_i64.should eq(5000388)
    end
  end

  describe "#at" do
    it "returns 0 if given precision is out of range" do
      tp = TimePoint.new(5000388, Scale::MICRO)
      tp[Scale.new(-3)].should eq(0_i16)
      tp[Scale.new(1)].should eq(0_i16)

      tp = TimePoint.new(1170, Scale::MILLI)
      tp[Scale::MICRO].should eq(0_i16)
      tp[Scale::KILO].should eq(0_i16)
    end
  end

  describe "#[]" do
    it "returns digit for given precision" do
      tp = TimePoint.new(5000388, Scale::BASE)
      tp[Scale::BASE].should eq(388_i16)
      tp[Scale::KILO].should eq(0_i16)
      tp[Scale::MEGA].should eq(5)

      tp = TimePoint.new(5000388, Scale::MICRO)
      tp[Scale::MICRO].should eq(388_i16)
      tp[Scale::MILLI].should eq(0_i16)
      tp[Scale::BASE].should eq(5)
    end

    it "returns digit at given index" do
      tp = TimePoint.new(5000388, Scale::BASE)
      tp[0].should eq(388_i16)
      tp[1].should eq(0_i16)
      tp[2].should eq(5)
    end
  end

  describe "#advance" do
    it "may expand to accomodate any scale" do
      tp = TimePoint.new
      tp.advance(Duration.new(5000388, Scale.new(-3)))
      tp.size.should eq(3)
      tp.precision.should eq(Scale.new(-3))
      tp.@magnitude.should eq([388, 0, 5])

      tp.advance(Duration.new(1777, Scale.new(-4)))
      tp.size.should eq(4)
      tp.precision.should eq(Scale.new(-4))
      tp.@magnitude.should eq([777, 389, 0, 5])

      tp = TimePoint.new
      tp.advance(Duration.new(5000388, Scale.new(3)))
      tp.size.should eq(3)
      tp.precision.should eq(Scale.new(3))
      tp.@magnitude.should eq([388, 0, 5])

      tp.advance(Duration.new(1777, Scale.new(2)))
      tp.size.should eq(4)
      tp.precision.should eq(Scale.new(2))
      tp.@magnitude.should eq([777, 389, 0, 5])
    end

    it "may shrink, resulting in coarsening the time precision" do
      tp = TimePoint.new
      tp.advance(Duration.new(600280777, Scale.new(-4)))
      tp.@magnitude.should eq([777, 280, 600])

      tp.advance(Duration.new(223, Scale.new(-4)))
      tp.size.should eq(2)
      tp.precision.should eq(Scale.new(-3))
      tp.@magnitude.should eq([281, 600])

      tp = TimePoint.new(600, 999, 777, precision: Scale.new(1))
      tp.advance(Duration.new(223, Scale.new(1)))
      tp.size.should eq(1)
      tp.precision.should eq(Scale.new(3))
      tp.@magnitude.should eq([601])
    end

    it "can exactly represent disparate scales" do
      tp1 = TimePoint.new(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, precision: Scale.new(-8))
      tp2 = TimePoint.new(1, precision: Scale.new(-8)).advance(Duration.new(1, Scale.new(8)), truncate: false)
      tp1.size.should eq(tp2.size)
      tp1.precision.should eq(tp2.precision)
      tp1.@magnitude.should eq(tp2.@magnitude)
    end

    it "can handle a negative duration value" do
      tp = TimePoint.new(5, 600, 280, 777, precision: Scale.new(-4))
      tp.advance(Duration.new(-5, Scale.new(-1)))
      tp.size.should eq(1)
      tp.@magnitude.should eq([0])
      tp.precision.should eq(Scale.new(-1))

      tp = TimePoint.new(5, 600, 280, 777, precision: Scale.new(1))
      tp.advance(Duration.new(-777, Scale.new(1)))
      tp.size.should eq(3)
      tp.@magnitude.should eq([280, 600, 5])
      tp.precision.should eq(Scale.new(2))

      tp = TimePoint.new(5010388)
      tp.advance(Duration.new(-2, Scale.new(1)))
      tp.size.should eq(2)
      tp.precision.should eq(Scale::KILO)
      tp.@magnitude.should eq([8, 5])
    end

    it "accomodates to the precision of the given duration" do
      tp = TimePoint.new(72, 800, 444, 321, precision: Scale::NANO)
      tp.advance(Duration.new(1150000000, Scale::NANO))
      tp.size.should eq(4)
      tp.precision.should eq(Scale::NANO)
      tp.@magnitude.should eq([321, 444, 950, 73])

      tp = TimePoint.new(72, 800, 444, 321, precision: Scale::NANO)
      tp.advance(Duration.new(1150000, Scale::MICRO))
      tp.size.should eq(3)
      tp.precision.should eq(Scale::MICRO)
      tp.@magnitude.should eq([444, 950, 73])

      tp = TimePoint.new(72, 800, 444, 321, precision: Scale::NANO)
      tp.advance(Duration.new(1150, Scale::MILLI))
      tp.size.should eq(2)
      tp.precision.should eq(Scale::MILLI)
      tp.@magnitude.should eq([950, 73])
    end
  end

  describe "#+(Duration)" do
    it "returns a new time point when added to a positive duration" do
      tp = TimePoint.new + Duration.new(5000388, Scale.new(-3))
      tp.size.should eq(3)
      tp.precision.should eq(Scale.new(-3))
      tp.@magnitude.should eq([388, 0, 5])

      tp = tp + Duration.new(1777, Scale.new(-4))
      tp.size.should eq(4)
      tp.precision.should eq(Scale.new(-4))
      tp.@magnitude.should eq([777, 389, 0, 5])

      tp = TimePoint.new + Duration.new(5000388, Scale.new(3))
      tp.size.should eq(3)
      tp.precision.should eq(Scale.new(3))
      tp.@magnitude.should eq([388, 0, 5])

      tp = tp + Duration.new(1777, Scale.new(2))
      tp.size.should eq(4)
      tp.precision.should eq(Scale.new(2))
      tp.@magnitude.should eq([777, 389, 0, 5])
    end

    it "may return a new coarsened time precision" do
      tp = TimePoint.new + Duration.new(600280777, Scale.new(-4))
      tp.@magnitude.should eq([777, 280, 600])

      tp = tp + Duration.new(223, Scale.new(-4))
      tp.size.should eq(2)
      tp.precision.should eq(Scale.new(-3))
      tp.@magnitude.should eq([281, 600])

      tp = TimePoint.new(600, 999, 777, precision: Scale.new(1))
      tp = tp + Duration.new(223, Scale.new(1))
      tp.size.should eq(1)
      tp.precision.should eq(Scale.new(3))
      tp.@magnitude.should eq([601])
    end

    it "returns an exact result with extremely disparate scales" do
      tp1 = TimePoint.new(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, precision: Scale.new(-8))
      tp2 = TimePoint.new(1, precision: Scale.new(-8)) + Duration.new(1, Scale.new(8))
      tp1.size.should eq(tp2.size)
      tp1.precision.should eq(tp2.precision)
      tp1.@magnitude.should eq(tp2.@magnitude)
    end

    it "can handle a negative value" do
      tp = TimePoint.new(5, 600, 280, 777, precision: Scale.new(-4))
      tp = tp + Duration.new(-5, Scale.new(-1))
      tp.size.should eq(3)
      tp.@magnitude.should eq([777, 280, 600])
      tp.precision.should eq(Scale.new(-4))

      tp = TimePoint.new(5, 600, 280, 777, precision: Scale.new(1))
      tp = tp + Duration.new(-777, Scale.new(1))
      tp.size.should eq(3)
      tp.@magnitude.should eq([280, 600, 5])
      tp.precision.should eq(Scale.new(2))

      tp = TimePoint.new(5010388) + Duration.new(-2, Scale.new(1))
      tp.size.should eq(3)
      tp.precision.should eq(Scale::BASE)
      tp.@magnitude.should eq([388, 8, 5])
    end
  end

  describe "#-(Duration)" do
    it "returns a new time point" do
      tp = TimePoint.new(5, 600, 280, 777, precision: Scale.new(-4))
      tp = tp - Duration.new(5, Scale.new(-1))
      tp.size.should eq(3)
      tp.@magnitude.should eq([777, 280, 600])
      tp.precision.should eq(Scale.new(-4))

      tp = TimePoint.new(5, 600, 280, 777, precision: Scale.new(1))
      tp = tp - Duration.new(777, Scale.new(1))
      tp.size.should eq(3)
      tp.@magnitude.should eq([280, 600, 5])
      tp.precision.should eq(Scale.new(2))

      tp = TimePoint.new(5010388) - Duration.new(2, Scale.new(1))
      tp.size.should eq(3)
      tp.precision.should eq(Scale::BASE)
      tp.@magnitude.should eq([388, 8, 5])
    end
  end

  describe "#-(TimePoint)" do
    it "returns the exact difference between two time points when possible" do
      a = TimePoint.new(31775100, Scale.new(-2))
      b = TimePoint.new(1170, Scale.new(-1))
      (a - b).should eq(Duration.new(30605100, Scale.new(-2)))
    end

    it "returns an infinite duration when the exact difference cannot be represented" do
      a = TimePoint.new(7, 3, 5, 6, 2, 9, precision: Scale.new(-5))
      b = TimePoint.new(6, Scale.new(0))
      (a - b).should eq(Duration::INFINITY)
    end

    it "approximates based on the result" do
      a = TimePoint.new(7, 3, 5, 6, 2, 9, precision: Scale.new(-5))
      b = TimePoint.new(7, Scale.new(0))
      (a - b).should eq(Duration.new(3005006002009, Scale.new(-5)))
    end
  end

  describe "#gap" do
    it "returns the exact difference between two time points when possible" do
      a = TimePoint.new(31775100, Scale.new(-2))
      b = TimePoint.new(1170, Scale.new(-1))
      a.gap(b).should eq(Duration.new(30605100, Scale.new(-2)))

      c = TimePoint.new(5, Scale.new(-4))
      d = TimePoint.new(982734, Scale.new(-1))
      d.gap(c).should eq(Duration.new(982733999999995, Scale.new(-4)))
    end

    it "returns a coarser precision when the exact difference cannot be represented" do
      a = TimePoint.new(7, 3, 5, 6, 2, 9, precision: Scale.new(-5))
      b = TimePoint.new(6, Scale.new(0))
      (a.gap(b)).should eq(Duration.new(1003005006002, Scale.new(-4)))

      a = TimePoint.new(5, 5, 5, 5, 5, 5, 5, 5, 5, 5, precision: Scale.new(-4))
      b = TimePoint.new(3, 3, 3, 3, 3, 3, 3, precision: Scale.new(3))
      b.gap(a).should eq(Duration.new(3_003_003_002_997, Scale.new(5)))
    end

    it "approximates based on the result" do
      a = TimePoint.new(7, 3, 5, 6, 2, 9, precision: Scale.new(-5))
      b = TimePoint.new(7, Scale.new(0))
      (a.gap(b)).should eq(Duration.new(3005006002009, Scale.new(-5)))
    end

    pending "should return a result within a single time quantum" do
      a = TimePoint.new(1)
      b = TimePoint.new(2800, Scale.new(-6))
      a.gap(b).should eq(Duration.new(999_999_999_999_997, Scale.new(-5)))

      a = TimePoint.new(1)
      b = TimePoint.new(2800, Scale.new(-6))
      a.gap(b).fixed_at(Scale.new(4)).should eq(Duration.new(100_000_000_000, Scale.new(-4)))

      a = TimePoint.new(1)
      b = TimePoint.new(2800, Scale.new(-6))
      # Although this is a closer approximation than the previous test, this
      # would be invalid since the error is not less than the resulting duration
      # time quantum of 1fs.
      a.gap(b).should_not eq(Duration.new(999_999_999_999_999, Scale.new(-5)))
    end
  end

  describe "comparison" do
    it "compares magnitudes" do
      a = TimePoint.new(1)
      b = TimePoint.new(1)

      (a <=> b).should eq(0)
      (a == b).should be_true

      b = TimePoint.new(1000, Scale::MILLI)
      (a <=> b).should eq(0)
      (a == b).should be_true

      b = TimePoint.new(1000000, Scale::MICRO)
      (a <=> b).should eq(0)
      (a == b).should be_true

      (TimePoint.new(2) > TimePoint.new(1000, Scale::MILLI)).should be_true
      (TimePoint.new(2) < TimePoint.new(3000, Scale::MILLI)).should be_true
    end
  end
end
