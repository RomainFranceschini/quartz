module Quartz
  module Verifiers
    class NumericalityChecker < EachChecker
      getter targets : Hash(Symbol, Number::Primitive)

      VALID_KEYS = {
        {:greater_than, :gt, :>},
        {:lesser_than, :lt, :<},
        {:greater_than_or_equal_to, :gte, :>=},
        {:lesser_than_or_equal_to, :lte, :<=},
        {:equal_to, :==},
        {:not_equal_to, :!=},
        {:negative},
        {:positive},
        {:zero},
        {:not_zero},
        {:finite},
        {:infinite},
      }

      # TODO what about big numbers?
      # TODO what about comparison within delta ?
      # TODO option for float comparison within error
      def initialize(*attributes, **kwargs)
        super(*attributes, **kwargs)
        @targets = Hash(Symbol, Number::Primitive).new

        VALID_KEYS.each do |tuple|
          tuple.each do |option|
            if (target = kwargs[option]?) && target.is_a?(Number)
              @targets[tuple[0]] = target
              break
            end
          end
        end
      end

      def check_each(model, attribute, value)
        return if value.nil? && allow_nil?

        if value.is_a?(Number)
          if value.responds_to?(:nan?)
            if value.nan?
              return if allow_nil?
              model.errors.add(attribute, "is not a number")
            end
          end

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
          elsif target = targets[:not_equal_to]?
            model.errors.add(attribute, "must be other than #{target}") if value == target
          end

          if target = targets[:positive]?
            model.errors.add(attribute, "must be positive") if value < 0
          elsif target = targets[:zero]?
            model.errors.add(attribute, "must be zero") if value != 0
          elsif target = targets[:negative]?
            model.errors.add(attribute, "must be negative") if value >= 0
          elsif target = targets[:not_zero]?
            model.errors.add(attribute, "must be other than 0") if value == 0
          end

          if target = targets[:finite]?
            if value.is_a?(Float)
              model.errors.add(attribute, "must be finite") if value.infinite?
            end
          elsif target = targets[:infinite]?
            unless value.is_a?(Float) && value.finite?
              model.errors.add(attribute, "must be infinite")
            end
          end
        end
      end
    end
  end
end
