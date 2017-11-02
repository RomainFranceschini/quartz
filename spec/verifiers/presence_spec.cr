require "../spec_helper"
require "../verifiable_helper"

describe "PresenceChecker" do
  context "with invalid attributes #check" do
    it "adds error for nil values" do
      model = MyModel.new(MyModel::State.new(buffer: nil))
      Verifiers::PresenceChecker.new(:buffer).check(model)
      model.errors[:buffer].should eq(["can't be nil"])
    end

    it "adds error for false values" do
      model = MyModel.new(MyModel::State.new(bool: false))
      Verifiers::PresenceChecker.new(:bool).check(model)
      model.errors[:bool].should eq(["can't be false"])
    end

    it "adds error for empty values" do
      model = MyModel.new(MyModel::State.new(string: "", buffer: [] of Int32))
      Verifiers::PresenceChecker.new(:string, :buffer).check(model)
      model.errors[:string].should eq(["can't be empty"])
      model.errors[:buffer].should eq(["can't be empty"])
    end

    it "adds error for NAN values" do
      model = MyModel.new(MyModel::State.new(number: Float32::NAN))
      Verifiers::PresenceChecker.new(:number).check(model)
      model.errors[:number].should eq(["can't be NAN"])
    end
  end

  context "with valid attributes #check" do
    it "don't adds error for non-nil values" do
      model = MyModel.new(MyModel::State.new(buffer: [1, 2] of Int32))
      Verifiers::PresenceChecker.new(:buffer).check(model)
      model.errors[:buffer].should be_nil
    end

    it "don't adds error for true values" do
      model = MyModel.new(MyModel::State.new(bool: true))
      Verifiers::PresenceChecker.new(:bool).check(model)
      model.errors[:bool].should be_nil
    end

    it "don't adds error for non-empty values" do
      model = MyModel.new(MyModel::State.new(string: "Hello", buffer: [1] of Int32))
      Verifiers::PresenceChecker.new(:string, :buffer).check(model)
      model.errors[:string].should be_nil
      model.errors[:buffer].should be_nil
    end

    it "don't adds error for non-NAN values" do
      model = MyModel.new(MyModel::State.new(number: 4.2f32))
      Verifiers::PresenceChecker.new(:number).check(model)
      model.errors[:number].should be_nil
    end
  end
end
