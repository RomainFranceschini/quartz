require "../spec_helper"
require "../validations_helper"

describe "NumericalityValidator" do
  describe "#validate" do
    context "greater than" do
      it "don't adds error for numbers greater than target" do
        model = NumericModel.new(int: 42)
        Validators::NumericalityValidator.new(:int, greater_than: 10).validate(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers equal to target" do
        model = NumericModel.new(int: 50)
        Validators::NumericalityValidator.new(:int, greater_than: 50).validate(model)
        model.errors[:int].should eq(["must be greater than 50"])
      end

      it "adds error for numbers lesser than target" do
        model = NumericModel.new(int: 1)
        Validators::NumericalityValidator.new(:int, greater_than: 10).validate(model)
        model.errors[:int].should eq(["must be greater than 10"])
      end
    end

    context "greater than or equal to" do
      it "don't adds error for numbers greater than target" do
        model = NumericModel.new(int: 42)
        Validators::NumericalityValidator.new(:int, greater_than_or_equal_to: 10).validate(model)
        model.errors[:int].should be_nil
      end

      it "don't adds error for numbers equal to target" do
        model = NumericModel.new(int: 42)
        Validators::NumericalityValidator.new(:int, greater_than_or_equal_to: 42).validate(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers lesser than target" do
        model = NumericModel.new(int: 1)
        Validators::NumericalityValidator.new(:int, greater_than_or_equal_to: 10).validate(model)
        model.errors[:int].should eq(["must be greater than or equal to 10"])
      end
    end

    context "lesser than" do
      it "don't adds error for numbers lesser than target" do
        model = NumericModel.new(int: 42)
        Validators::NumericalityValidator.new(:int, lesser_than: 50).validate(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers equal to target" do
        model = NumericModel.new(int: 50)
        Validators::NumericalityValidator.new(:int, lesser_than: 50).validate(model)
        model.errors[:int].should eq(["must be lesser than 50"])
      end

      it "adds error for numbers greater than target" do
        model = NumericModel.new(int: 65)
        Validators::NumericalityValidator.new(:int, lesser_than: 50).validate(model)
        model.errors[:int].should eq(["must be lesser than 50"])
      end
    end

    context "lesser than or equal to" do
      it "don't adds error for numbers lesser than target" do
        model = NumericModel.new(int: 42)
        Validators::NumericalityValidator.new(:int, lesser_than_or_equal_to: 50).validate(model)
        model.errors[:int].should be_nil
      end

      it "don't adds error for numbers equal to target" do
        model = NumericModel.new(int: 42)
        Validators::NumericalityValidator.new(:int, lesser_than_or_equal_to: 42).validate(model)
        model.errors[:int].should be_nil
      end

      it "adds error for numbers greater than target" do
        model = NumericModel.new(int: 65)
        Validators::NumericalityValidator.new(:int, lesser_than_or_equal_to: 50).validate(model)
        model.errors[:int].should eq(["must be lesser than or equal to 50"])
      end
    end
  end
end
