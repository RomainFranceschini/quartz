require "../spec_helper"
require "../validations_helper"

describe "PresenceValidator" do
  context "with invalid attributes #validate" do
    it "adds error for nil values" do
      model = MyModel.new(buffer: nil)
      Validators::PresenceValidator.new(:buffer).validate(model)
      model.errors[:buffer].should eq(["can't be nil"])
    end

    it "adds error for false values" do
      model = MyModel.new(bool: false)
      Validators::PresenceValidator.new(:bool).validate(model)
      model.errors[:bool].should eq(["can't be false"])
    end

    it "adds error for empty values" do
      model = MyModel.new(string: "", buffer: [] of Int32)
      Validators::PresenceValidator.new(:string, :buffer).validate(model)
      model.errors[:string].should eq(["can't be empty"])
      model.errors[:buffer].should eq(["can't be empty"])
    end

    it "adds error for NAN values" do
      model = MyModel.new(number: Float32::NAN)
      Validators::PresenceValidator.new(:number).validate(model)
      model.errors[:number].should eq(["can't be NAN"])
    end
  end

  context "with valid attributes #validate" do
    it "don't adds error for non-nil values" do
      model = MyModel.new(buffer: [1, 2] of Int32)
      Validators::PresenceValidator.new(:buffer).validate(model)
      model.errors[:buffer].should be_nil
    end

    it "don't adds error for true values" do
      model = MyModel.new(bool: true)
      Validators::PresenceValidator.new(:bool).validate(model)
      model.errors[:bool].should be_nil
    end

    it "don't adds error for non-empty values" do
      model = MyModel.new(string: "Hello", buffer: [1] of Int32)
      Validators::PresenceValidator.new(:string, :buffer).validate(model)
      model.errors[:string].should be_nil
      model.errors[:buffer].should be_nil
    end

    it "don't adds error for non-NAN values" do
      model = MyModel.new(number: 4.2f32)
      Validators::PresenceValidator.new(:number).validate(model)
      model.errors[:number].should be_nil
    end
  end
end
