module Quartz
  module Validators
    # A simple base class that can be used along with `Validations#validates_with`
    #
    # ```
    # class MyModel
    #   include Validations
    #   validates_with MyValidator
    # end
    #
    # class MyValidator < Validator
    #   def validate(model)
    #     if some_complex_logic
    #       model.errors.add(:base, "This model is invalid")
    #     end
    #   end
    #
    #   private def some_complex_logic
    #     # ...
    #   end
    # end
    # ```
    #
    # Any class that inherits from `Validator` must implement a
    # method called `#validate` which accepts a *model*.
    #
    # ```
    # class MyModel
    #   include Validations
    #   validates_with MyValidator
    # end
    #
    # class MyValidator < Validator
    #   def validate(model)
    #     model # => The model instance being validated
    #   end
    # end
    # ```
    #
    # To cause a validation error, you must add to the *model*'s errors directly
    # from within the validators message.
    #
    # ```
    # class MyValidator < Validator
    #   def validate(model)
    #     model.errors.add :attr1, "This is some custom error message"
    #     model.errors.add :attr2, "This is some complex validation"
    #     # etc...
    #   end
    # end
    # ```
    #
    # Note that the validator is initialized only once for the whole application
    # life cycle, and not on each validation run.
    abstract class Validator
      getter context : Symbol?

      def initialize(**kwargs)
        @context = kwargs[:on]?.try &.as(Symbol)
      end

      # Override this method in subclasses with validation logic, adding errors
      # to the models *errors* array where necessary.
      abstract def validate(model)
    end

    # `EachValidator` is a validator which iterates through the given
    # *attributes* invoking the `#validate_each` method passing in the
    # model, attribute and value.
    #
    # All provided validators are built on top of this validator.
    abstract class EachValidator < Validator
      getter attributes : Array(Symbol)
      @allow_nil : Bool

      def allow_nil? : Bool
        @allow_nil
      end

      # Returns a new validator instance. The given *attributes* are made
      # available through the `#attributes` getter.
      def initialize(*attributes : Symbol, **kwargs)
        raise ArgumentError.new("attributes cannot be empty") if attributes.empty?
        @attributes = attributes.to_a
        @allow_nil = kwargs[:allow_nil]?.try(&.as(Bool)) || false
        super(**kwargs)
      end

      # Performs validation on the supplied model. By default this will call
      # `#validates_each` to determine validity therefore subclasses should
      # override `#validates_each` with validation logic.
      def validate(model)
        model_attributes = model.attributes
        attributes.each do |attribute|
          value = model_attributes[attribute]
          next if (value.nil? && allow_nil?)
          validate_each(model, attribute, value)
        end
      end

      # Override this method in subclasses with the validation logic, adding
      # errors to the records +errors+ array where necessary.
      abstract def validate_each(model, attribute, value)
    end

    # `BlockValidator` is a special `EachValidator` which receives a block on
    # initialization and call this block for each attribute being validated.
    # `#validates_each` uses this validator.
    class BlockValidator < EachValidator
      def initialize(*attributes, **kwargs, &block)
        super(*attributes, **kwargs)
        @block = block
      end

      private def validate_each(model, attribute, value)
        @block.call(model, attribute, value)
      end
    end
  end
end
