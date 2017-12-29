require "./spec_helper"

describe "VerificationErrors" do
  describe "#add" do
    context "with string" do
      it "append error to the attribute list of errors" do
        errors = Quartz::VerificationErrors.new
        errors.add(:name, "My first error")
        errors.add(:age, "My second error")
        errors.add(:age, "My third error")
        errors.messages.should eq({
          :name => ["My first error"],
          :age  => ["My second error", "My third error"],
        })
      end
    end

    context "with array of strings" do
      it "append multiple errors to the attribute list of errors" do
        errors = Quartz::VerificationErrors.new
        errors.add(:name, "My first error")
        errors.add(:age, "My second error", "My third error")
        errors.messages.should eq({
          :name => ["My first error"],
          :age  => ["My second error", "My third error"],
        })
      end
    end
  end

  describe "#clear" do
    it "clear list of errors" do
      errors = Quartz::VerificationErrors.new
      errors.add(:age, "My second error", "My third error")
      errors.clear
      errors.messages.should eq({} of Symbol => Array(String))
    end
  end

  describe "#size" do
    it "returns 0 when there are no errors" do
      errors = Quartz::VerificationErrors.new
      errors.size.should eq(0)

      errors.add(:name, "My first error")
      errors.clear
      errors.size.should eq(0)
    end

    it "counts all errors" do
      errors = Quartz::VerificationErrors.new
      errors.add(:name, "My first error")
      errors.add(:age, "My second error", "My third error")
      errors.size.should eq(3)
    end
  end

  describe "#include?" do
    it "is truthy when given attribute has errors" do
      errors = Quartz::VerificationErrors.new
      errors.add(:name, "My first error")
      errors.include?(:name).should be_true
    end

    it "is falsey when given attribute has no errors" do
      errors = Quartz::VerificationErrors.new
      errors.include?(:test).should be_false

      errors.add(:name, "My first error")
      errors.clear
      errors.include?(:name).should be_false
    end
  end

  describe "#[]" do
    it "returns list of errors" do
      errors = Quartz::VerificationErrors.new
      errors.add(:name, "My first error")
      errors[:name].should eq(["My first error"])
    end

    it "returns nil when there are no errors" do
      errors = Quartz::VerificationErrors.new
      errors[:name].should be_nil

      errors.add(:name, "My first error")
      errors.clear

      errors[:name].should be_nil
    end
  end
end
