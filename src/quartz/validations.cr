require "./validators/validator"
require "./validators/presence"
require "./validators/numericality"

module Quartz
  module Validations
    macro included
      def self.validators
        @@validators ||= {} of Symbol => Array(Validators::AbstractValidator)
      end

      def self.clear_validators
        @@validators.clear
      end

      def self.validates(*attributes : Symbol, **kwargs)
        if kwargs.empty?
          raise ArgumentError.new("You must inform at least one validation rule")
        end


      end

      # TODO: Copy validators on inheritance
      macro inherited

      end
    end

    # Returns the `Errors` object that holds all information about attribute
    # error messages.
    getter(errors) { Quartz::Errors.new }

    def attributes
      values = {{ ("{} of Symbol => " + @type.instance_vars.map(&.type).join("|")).id }}
      {% for ivar in @type.instance_vars %}
        {% unless ivar.id.ends_with?("errors") && ivar.id.size == "errors".size %}
          values[:"{{ ivar.id }}"] = @{{ ivar.id }}
        {% end %}
      {% end %}
      values
    end

    def valid? : Bool

    end

    def valid?(context : Symbol) : Bool

    end


  end
end
