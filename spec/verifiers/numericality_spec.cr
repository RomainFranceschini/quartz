require "../spec_helper"
require "../verifiable_helper"

describe "NumericalityChecker" do
  describe "#check" do
    context "greater than" do
      it "don't adds error for numbers greater than target" do
        model = NumericModel.new(NumericModel::State.new(int: 42))
        Verifiers::NumericalityChecker.new(:int, greater_than: 10).check(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers equal to target" do
        model = NumericModel.new(NumericModel::State.new(int: 50))
        Verifiers::NumericalityChecker.new(:int, greater_than: 50).check(model)
        model.errors[:int].should eq(["must be greater than 50"])
      end

      it "adds error for numbers lesser than target" do
        model = NumericModel.new(NumericModel::State.new(int: 1))
        Verifiers::NumericalityChecker.new(:int, greater_than: 10).check(model)
        model.errors[:int].should eq(["must be greater than 10"])
      end
    end

    context "greater than or equal to" do
      it "don't adds error for numbers greater than target" do
        model = NumericModel.new(NumericModel::State.new(int: 42))
        Verifiers::NumericalityChecker.new(:int, greater_than_or_equal_to: 10).check(model)
        model.errors[:int].should be_nil
      end

      it "don't adds error for numbers equal to target" do
        model = NumericModel.new(NumericModel::State.new(int: 42))
        Verifiers::NumericalityChecker.new(:int, greater_than_or_equal_to: 42).check(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers lesser than target" do
        model = NumericModel.new(NumericModel::State.new(int: 1))
        Verifiers::NumericalityChecker.new(:int, greater_than_or_equal_to: 10).check(model)
        model.errors[:int].should eq(["must be greater than or equal to 10"])
      end
    end

    context "lesser than" do
      it "don't adds error for numbers lesser than target" do
        model = NumericModel.new(NumericModel::State.new(int: 42))
        Verifiers::NumericalityChecker.new(:int, lesser_than: 50).check(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers equal to target" do
        model = NumericModel.new(NumericModel::State.new(int: 50))
        Verifiers::NumericalityChecker.new(:int, lesser_than: 50).check(model)
        model.errors[:int].should eq(["must be lesser than 50"])
      end

      it "adds error for numbers greater than target" do
        model = NumericModel.new(NumericModel::State.new(int: 65))
        Verifiers::NumericalityChecker.new(:int, lesser_than: 50).check(model)
        model.errors[:int].should eq(["must be lesser than 50"])
      end
    end

    context "lesser than or equal to" do
      it "don't adds error for numbers lesser than target" do
        model = NumericModel.new(NumericModel::State.new(int: 42))
        Verifiers::NumericalityChecker.new(:int, lesser_than_or_equal_to: 50).check(model)
        model.errors[:int].should be_nil
      end

      it "don't adds error for numbers equal to target" do
        model = NumericModel.new(NumericModel::State.new(int: 42))
        Verifiers::NumericalityChecker.new(:int, lesser_than_or_equal_to: 42).check(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers greater than target" do
        model = NumericModel.new(NumericModel::State.new(int: 65))
        Verifiers::NumericalityChecker.new(:int, lesser_than_or_equal_to: 50).check(model)
        model.errors[:int].should eq(["must be lesser than or equal to 50"])
      end
    end

    context "equal to" do
      it "adds error for numbers greater than target" do
        model = NumericModel.new(NumericModel::State.new(int: 65))
        Verifiers::NumericalityChecker.new(:int, equal_to: 50).check(model)
        model.errors[:int].should eq(["must be equal to 50"])
      end

      it "adds error for numbers lesser than target" do
        model = NumericModel.new(NumericModel::State.new(int: 9))
        Verifiers::NumericalityChecker.new(:int, equal_to: 50).check(model)
        model.errors[:int].should eq(["must be equal to 50"])
      end

      it "don't adds errors for numbers equal to target" do
        model = NumericModel.new(NumericModel::State.new(int: 50))
        Verifiers::NumericalityChecker.new(:int, equal_to: 50).check(model)
        model.errors[:int].should be_nil
      end
    end

    context "not equal to" do
      it "don't adds error for numbers greater than target" do
        model = NumericModel.new(NumericModel::State.new(int: 65))
        Verifiers::NumericalityChecker.new(:int, not_equal_to: 50).check(model)
        model.errors[:int].should be_nil
      end

      it "don't adds error for numbers lesser than target" do
        model = NumericModel.new(NumericModel::State.new(int: 9))
        Verifiers::NumericalityChecker.new(:int, not_equal_to: 50).check(model)
        model.errors[:int].should be_nil
      end

      it "adds errors for numbers equal to target" do
        model = NumericModel.new(NumericModel::State.new(int: 50))
        Verifiers::NumericalityChecker.new(:int, not_equal_to: 50).check(model)
        model.errors[:int].should eq(["must be other than 50"])
      end
    end

    context "allow nil" do
      it "don't adds error if number is nan?" do
        model = NumericModel.new(NumericModel::State.new(float: Float64::NAN))
        Verifiers::NumericalityChecker.new(:float, allow_nil: true).check(model)
        model.errors[:float].should be_nil
      end
    end

    context "don't allow nil" do
      it "don't adds error if number is nan?" do
        model = NumericModel.new(NumericModel::State.new(float: Float64::NAN))
        Verifiers::NumericalityChecker.new(:float, allow_nil: false).check(model)
        model.errors[:float].should eq(["is not a number"])
      end
    end
  end
end
