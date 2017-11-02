require "./verifiers/checker"
require "./verifiers/presence"
require "./verifiers/numericality"

module Quartz
  # Provides a runtime verification framework for your models.
  #
  # Example:
  # ```
  # class WeightModel
  #   include Quartz::Verifiable
  #
  #   property weight : Float64 = 0.0 # in kg
  #   check :weight, numericality: {greater_than: 40, lesser_than: 160}
  # end
  #
  # model = WeightModel.new
  # model.weight = 75.0
  # model.valid?   # => true
  # model.invalid? # => false
  #
  # model.weight = 200.0
  # model.valid?          # => false
  # model.invalid?        # => true
  # model.errors.messages # => { :weight => ["must be lesser than 160"] }
  # ```
  module Verifiable
    macro included
      def self.verifiers
        @@verifiers ||= Array(Verifiers::RuntimeChecker).new
      end

      def self.clear_verifiers
        @@verifiers.try &.clear
      end

      def self.check(*attributes : Symbol, **kwargs)
        if kwargs.empty?
          raise ArgumentError.new("You must inform at least one verification rule")
        end

        kwargs.each do |name, value|
          verifier = case name
          when :presence
            if value.is_a?(NamedTuple)
              Verifiers::PresenceChecker.new(*attributes, **value)
            else
              Verifiers::PresenceChecker.new(*attributes)
            end
          when :numericality
            if value.is_a?(NamedTuple)
              Verifiers::NumericalityChecker.new(*attributes, **value)
            else
              Verifiers::NumericalityChecker.new(*attributes)
            end
          else
            raise ArgumentError.new("Unknown verifier \"#{name}\"")
          end

          verifiers.push(verifier)
        end
      end

      # Passes the model off to the class or classes specified and allows them
      # to add errors based on more complex conditions.
      #
      # ```
      # class MyModel
      #   include Quartz::Verifiable
      #   check_with MyVerifier
      # end
      #
      # class MyVerifier < Quartz::Verifiers::EachChecker
      #   def check_each(model, attribute, value)
      #     if some_test
      #       model.errors.add(attribute, "This model attribute is invalid")
      #     end
      #   end
      #
      #   # ...
      # end
      # ```
      def self.check_with(klass : Verifiers::EachChecker.class, *attributes : Symbol, **kwargs)
        verifier = klass.new(*attributes, **kwargs)
        verifiers.push(verifier)
      end

      # Passes the model off to the class or classes specified and allows them
      # to add errors based on more complex conditions.
      #
      # ```
      # class MyModel
      #   include Quartz::Verifiable
      #   check_with MyVerifier
      # end
      #
      # class MyVerifier < Quartz::Verifiers::RuntimeChecker
      #   def validate(model)
      #     if some_test
      #       model.errors.add(:phase, "This model state is invalid")
      #     end
      #   end
      #
      #   # ...
      # end
      # ```
      def self.check_with(klass : Verifiers::RuntimeValidator.class, **kwargs)
        verifier = klass.new(**kwargs)
        verifiers.push(verifier)
      end

      # TODO: Copy verifiers on inheritance
      macro inherited
      end
    end

    # Returns the `VerificationErrors` object that holds all information about
    # attribute error messages.
    getter(errors) { Quartz::VerificationErrors.new }

    # Clears attribute error messages.
    def clear_errors
      @errors.try &.clear
    end

    # Runs all the specified verifications and returns *true* if no errors were
    # added otherwise *false*.
    #
    def valid?(context : Symbol? = nil) : Bool
      errors.clear
      run_verifiers(context)
      errors.empty?
    end

    # Performs the opposite of `#valid?`. Returns *true* if errors were added,
    # *false* otherwise.
    #
    # Usage:
    # ```
    # class MyModel
    #   include Quartz::Verifiable
    #
    #   property :phase : String?
    #   check :phase, presence: true
    # end
    #
    # model = MyModel.new
    # model.phase = ""
    # model.invalid?          # => true
    # model.phase = "idle"
    # model.invalid?          # => false
    # ```
    #
    # Context can optionally be supplied to define which verifiers to test
    # against (the context is defined on the verifiers using *on:* option).
    def invalid?(context : Symbol? = nil) : Bool
      !valid?(context)
    end

    # :nodoc:
    protected def run_verifiers(context : Symbol? = nil)
      self.class.verifiers.each do |verifier|
        contexts = verifier.contexts
        if !contexts || contexts.includes?(context)
          if !verifier.check(self) && verifier.strict?
            raise StrictVerificationFailed.new(errors)
          end
        end
      end
    end
  end
end
