require "./spec_helper"
require "./verifiable_helper"

describe "Verifiable" do
  describe ".check" do
    it "requires at least one verification rule" do
      expect_raises ArgumentError, "You must inform at least one verification rule" do
        MyModel.check :test
      end
    end

    it "does not allow invalid verification rules" do
      expect_raises ArgumentError, "Unknown verifier \"unknown_verifier\"" do
        MyModel.check :number, unknown_verifier: true
      end
    end
  end

  describe ".clear_verifiers" do
    it "removes all verifiers associated with the class" do
      MyModel.check :number, presence: true
      MyModel.check :string, presence: true

      MyModel.verifiers.size.should eq(2)
      MyModel.clear_verifiers
      MyModel.verifiers.size.should eq(0)
    end
  end

  describe "#errors" do
    it "returns an instance of VerificationErrors" do
      model = MyModel.new
      model.errors.should be_a(VerificationErrors)
    end
  end

  describe "#valid?" do
    context "without verification rules" do
      it "returns always true" do
        MyModel.new.valid?.should be_true
      end
    end

    context "with strict verifiers" do
      it "raises an error when invalid" do
        MyModel.check :buffer, presence: {strict: true}
        expect_raises StrictVerificationFailed do
          model = MyModel.new.valid?
        end
        MyModel.clear_verifiers
      end
    end

    context "with valid attributes" do
      it "returns true" do
        MyModel.check :buffer, presence: true
        model = MyModel.new
        model.buffer = [1, 2]
        model.valid?.should be_true
        MyModel.clear_verifiers
      end

      context "after unsuccessful validation" do
        it "returns true" do
          MyModel.check :number, presence: true
          model = MyModel.new
          model.number = Float32::NAN
          model.valid?.should be_false
          model.number = 42.0f32
          model.valid?.should be_true
          MyModel.clear_verifiers
        end
      end
    end

    context "with invalid attributes" do
      it "returns false" do
        MyModel.check :string, presence: true
        model = MyModel.new
        model.string = ""
        model.valid?.should be_false
        MyModel.clear_verifiers
      end

      it "adds error messages" do
        MyModel.check :bool, :string, presence: true
        model = MyModel.new
        model.bool = false
        model.string = ""
        model.valid?.should be_false

        model.errors.empty?.should be_false
        model.errors.messages.has_key?(:bool).should be_true
        model.errors.messages.has_key?(:string).should be_true
        model.errors.messages[:bool].size.should_not eq(0)
        model.errors.messages[:string].size.should_not eq(0)

        MyModel.clear_verifiers
      end

      context "and a given context" do
        MyModel.check(:number, numericality: {greater_than: 20, on: :some_context})

        it "verifiers with matching context adds error messages" do
          model = MyModel.new
          model.number = 0.0f32

          model.invalid?(:some_context).should be_true

          model.errors.messages.has_key?(:number).should be_true
          model.errors.messages[:number].size.should eq(1)
          model.errors.messages[:number].first.should eq("must be greater than 20")
        end

        it "verifiers that doesn't match context don't add errors" do
          model = MyModel.new
          model.number = 0f32

          model.valid?(:other_context).should be_true

          model.errors.empty?.should be_true
          model.errors.messages.has_key?(:number).should be_false
        end

        MyModel.clear_verifiers
      end
    end
  end
end
