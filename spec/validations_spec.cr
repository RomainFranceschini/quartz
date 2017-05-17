require "./spec_helper"
require "./validations_helper"

describe "Validations" do
  describe ".validates" do
    it "requires at least one validation rule" do
      expect_raises ArgumentError, "You must inform at least one validation rule" do
        MyModel.validates :test
      end
    end

    it "does not allow invalid validation rules" do
      expect_raises ArgumentError, "Unknown validator \"unknown_validator\"" do
        MyModel.validates :number, unknown_validator: true
      end
    end
  end

  describe ".clear_validators" do
    it "removes all validators associated with the class" do
      MyModel.validates :number, presence: true
      MyModel.validates :string, presence: true

      MyModel.validators.size.should eq(2)
      MyModel.clear_validators
      MyModel.validators.size.should eq(0)
    end
  end

  describe "#errors" do
    it "returns an instance of ValidationErrors" do
      model = MyModel.new
      model.errors.should be_a(ValidationErrors)
    end
  end

  describe "#valid?" do
    context "without validation rules" do
      it "returns always true" do
        MyModel.new.valid?.should be_true
      end
    end

    context "with strict validators" do
      it "raises an error when invalid" do
        MyModel.validates :buffer, presence: { strict: true }
        expect_raises StrictValidationFailed do
          model = MyModel.new.valid?
        end
        MyModel.clear_validators
      end
    end

    context "with valid attributes" do
      it "returns true" do
        MyModel.validates :buffer, presence: true
        model = MyModel.new
        model.buffer = [1,2]
        model.valid?.should be_true
        MyModel.clear_validators
      end

      context "after unsuccessful validation" do
        it "returns true" do
          MyModel.validates :number, presence: true
          model = MyModel.new
          model.number = Float32::NAN
          model.valid?.should be_false
          model.number = 42.0f32
          model.valid?.should be_true
          MyModel.clear_validators
        end
      end
    end

    context "with invalid attributes" do
      it "returns false" do
        MyModel.validates :string, presence: true
        model = MyModel.new
        model.string = ""
        model.valid?.should be_false
        MyModel.clear_validators
      end

      it "adds error messages" do
        MyModel.validates :bool, :string, presence: true
        model = MyModel.new
        model.bool = false
        model.string = ""
        model.valid?.should be_false

        model.errors.empty?.should be_false
        model.errors.messages.has_key?(:bool).should be_true
        model.errors.messages.has_key?(:string).should be_true
        model.errors.messages[:bool].size.should_not eq(0)
        model.errors.messages[:string].size.should_not eq(0)

        MyModel.clear_validators
      end

      context "and a given context" do
        MyModel.validates(:number, numericality: { greater_than: 20, on: :some_context })

        it "validators with matching context adds error messages" do
          model = MyModel.new
          model.number = 0.0f32

          model.invalid?(:some_context).should be_true

          model.errors.messages.has_key?(:number).should be_true
          model.errors.messages[:number].size.should eq(1)
          model.errors.messages[:number].first.should eq("must be greater than 20")
        end

        it "validators that doesn't match context don't add errors" do
          model = MyModel.new
          model.number = 0f32

          model.valid?(:other_context).should be_true

          model.errors.empty?.should be_true
          model.errors.messages.has_key?(:number).should be_false
        end

        MyModel.clear_validators
      end
    end
  end
end
