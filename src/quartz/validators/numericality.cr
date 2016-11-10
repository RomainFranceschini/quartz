module Quartz
  module Validators
    class NumericalityValidator < EachValidator
      getter targets : Hash(Symbol, AnyNumber)

      # TODO what about big numbers?
      # TODO option for float comparison within error
      def initialize(*attributes, allow_nil = false, **options : AnyNumber)
        super(*attributes, allow_nil: allow_nil)
        @targets = Hash(Symbol, AnyNumber).new

        keys = {
          {:greater_than,:gt,:>},
          {:lesser_than,:lt,:<},
          {:greater_than_or_equal_to,:gte,:>=},
          {:lesser_than_or_equal_to,:lte,:<=},
          {:equal_to,:==},
          {:other_than,:!=}
        }

        keys.each do |tuple|
          tuple.each do |option|
            if target = options[option]?
              @targets[tuple[0]] = target
              #break # see issue #3529
            end
          end
        end
      end

      def validate_each(model, attribute, value)
        if value.is_a?(Number)
          if target = @targets[:greater_than]?
            model.errors.add(attribute, "must be greater than #{target}") if value <= target
          end

          if target = targets[:lesser_than]?
            model.errors.add(attribute, "must be lesser than #{target}") if value >= target
          end

          if target = targets[:greater_than_or_equal_to]?
            model.errors.add(attribute, "must be greater than or equal to #{target}") if value < target
          end

          if target = targets[:lesser_than_or_equal_to]?
            model.errors.add(attribute, "must be lesser than or equal to #{target}") if value > target
          end

          if target = targets[:equal_to]?
            model.errors.add(attribute, "must be equal to #{target}") if value != target
          end

          if target = targets[:other_than]?
            model.errors.add(attribute, "must be other than #{target}") if value == target
          end
        end
      end
    end
  end
end
