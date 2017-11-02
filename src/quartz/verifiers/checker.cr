module Quartz
  module Verifiers
    # A simple base class that can be used along with `Verifiable#check_with`
    #
    # ```
    # class MyModel
    #   include Verifiable
    #   check_with MyVerifier
    # end
    #
    # class MyVerifier < RuntimeChecker
    #   def check(model)
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
    # Any class that inherits from `RuntimeChecker` must implement a
    # method called `#check` which accepts a *model*.
    #
    # ```
    # class MyModel
    #   include Verifiable
    #   check_with MyVerifier
    # end
    #
    # class MyVerifier < RuntimeChecker
    #   def check(model)
    #     model # => The model instance being validated
    #   end
    # end
    # ```
    #
    # To cause a verification error, you must add to the *model*'s errors
    # directly from within the verifiers message.
    #
    # ```
    # class MyVerifier < RuntimeChecker
    #   def check(model)
    #     model.errors.add :attr1, "This is some custom error message"
    #     model.errors.add :attr2, "This is some complex validation"
    #     # etc...
    #   end
    # end
    # ```
    #
    # Note that the verifier is initialized only once for the whole application
    # life cycle, and not on each verification run.
    abstract class RuntimeChecker
      @strict : Bool
      getter contexts : Array(Symbol)?

      # Whether this verifier will cause a `StrictVerificationFailed` error to
      # be raised when `#check` returns *false*.
      def strict?
        @strict
      end

      def initialize(**kwargs)
        if on = kwargs[:on]?
          if on.is_a?(Array(Symbol))
            @contexts = on
          elsif on.is_a?(Symbol)
            @contexts = [on]
          end
        end

        @strict = kwargs[:strict]?.try(&.as(Bool)) || false
      end

      # Override this method in subclasses with verification logic, adding errors
      # to the models *errors* array where necessary.
      abstract def check(model) : Bool
    end

    # `EachChecker` is a verifier which iterates through the given
    # *attributes* invoking the `#check_each` method passing in the
    # model, attribute and value.
    #
    # All provided verifiers are built on top of this verifier.
    abstract class EachChecker < RuntimeChecker
      getter attributes : Array(Symbol)

      @allow_nil : Bool

      def allow_nil? : Bool
        @allow_nil
      end

      # Returns a new verifier instance. The given *attributes* are made
      # available through the `#attributes` getter.
      def initialize(*attributes : Symbol, **kwargs)
        raise ArgumentError.new("attributes cannot be empty") if attributes.empty?
        @attributes = attributes.to_a
        @allow_nil = kwargs[:allow_nil]?.try(&.as(Bool)) || false
        super(**kwargs)
      end

      # Performs verification on the supplied model. By default this will call
      # `#check_each` to determine validity therefore subclasses should
      # override `#check_each` with verification logic.
      def check(model) : Bool
        model_attributes = model.state.to_named_tuple
        @attributes.each do |attribute|
          value = model_attributes[attribute]
          next if (value.nil? && @allow_nil)
          check_each(model, attribute, value)
        end
        model.errors.empty?
      end

      # Override this method in subclasses with the verification logic, adding
      # errors to the records *errors* array where necessary.
      abstract def check_each(model, attribute, value)
    end
  end
end
