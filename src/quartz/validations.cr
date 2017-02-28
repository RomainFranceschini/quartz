require "./validators/validator"
require "./validators/presence"
require "./validators/numericality"

module Quartz
  # Provides a validation framework for your models.
  #
  # Example:
  # ```
  # class WeightModel
  #   include Quartz::Validations
  #
  #   property weight : Float64 = 0.0 # in kg
  #   validates :weight, numericality: {greater_than: 40, lesser_than: 160}
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
  module Validations
    macro included
      def self.validators
        @@validators ||= Array(Validators::Validator).new
      end

      def self.clear_validators
        @@validators.try &.clear
      end

      def self.validates(*attributes : Symbol, **kwargs)
        if kwargs.empty?
          raise ArgumentError.new("You must inform at least one validation rule")
        end

        kwargs.each do |name, value|
          validator = case name
          when :presence
            if value.is_a?(NamedTuple)
              Validators::PresenceValidator.new(*attributes, **value)
            else
              Validators::PresenceValidator.new(*attributes)
            end
          when :numericality
            if value.is_a?(NamedTuple)
              Validators::NumericalityValidator.new(*attributes, **value)
            else
              Validators::NumericalityValidator.new(*attributes)
            end
          else
            raise ArgumentError.new("Unknown validator \"#{name}\"")
          end

          validators.push(validator)
        end
      end

      # Passes the model off to the class or classes specified and allows them
      # to add errors based on more complex conditions.
      #
      # ```
      # class MyModel
      #   include Quartz::Validations
      #   validates_with MyValidator
      # end
      #
      # class MyValidator < Quartz::Validators::EachValidator
      #   def validate_each(model, attribute, value)
      #     if some_test
      #       model.errors.add(attribute, "This model attribute is invalid")
      #     end
      #   end
      #
      #   # ...
      # end
      # ```
      def self.validates_with(klass : Validators::EachValidator.class, *attributes : Symbol, **kwargs)
        validator = klass.new(*attributes, **kwargs)
        validators.push(validator)
      end

      # Passes the model off to the class or classes specified and allows them
      # to add errors based on more complex conditions.
      #
      # ```
      # class MyModel
      #   include Quartz::Validations
      #   validates_with MyValidator
      # end
      #
      # class MyValidator < Quartz::Validators::Validator
      #   def validate(model)
      #     if some_test
      #       model.errors.add(:phase, "This model state is invalid")
      #     end
      #   end
      #
      #   # ...
      # end
      # ```
      def self.validates_with(klass : Validators::Validator.class, **kwargs)
        validator = klass.new(**kwargs)
        validators.push(validator)
      end

      # TODO: Copy validators on inheritance
      macro inherited
      end
    end

    # Returns the `ValidationErrors` object that holds all information about
    # attribute error messages.
    getter(errors) { Quartz::ValidationErrors.new }

    # Clears attribute error messages.
    def clear_errors
      @errors.try &.clear
    end

    def attributes
      values = {{ ("{} of Symbol => " + @type.instance_vars.map(&.type).join("|")).id }}
      {% for ivar in @type.instance_vars %}
        {% unless ivar.id.ends_with?("errors") && ivar.id.size == "errors".size %}
          values[:"{{ ivar.id }}"] = @{{ ivar.id }}
        {% end %}
      {% end %}
      values
    end

    # Runs all the specified validations and returns *true* if no errors were
    # added otherwise *false*.
    #
    def valid?(context : Symbol? = nil) : Bool
      errors.clear
      run_validators(context)
      errors.empty?
    end

    # Performs the opposite of `#valid?`. Returns *true* if errors were added,
    # *false* otherwise.
    #
    # Usage:
    # ```
    # class MyModel
    #   include Quartz::Validations
    #
    #   property :phase : String?
    #   validates :phase, presence: true
    # end
    #
    # model = MyModel.new
    # model.phase = ""
    # model.invalid?          # => true
    # model.phase = "idle"
    # model.invalid?          # => false
    # ```
    #
    # Context can optionally be supplied to define which validators to test
    # against (the context is defined on the validators using *on:* option).
    def invalid?(context : Symbol? = nil) : Bool
      !valid?(context)
    end

    protected def run_validators(context : Symbol? = nil)
      self.class.validators.each do |validator|
        contexts = validator.contexts
        if !contexts || contexts.includes?(context)
          if !validator.validate(self) && validator.strict?
            raise StrictValidationFailed.new(errors)
          end
        end
      end
    end
  end
end
