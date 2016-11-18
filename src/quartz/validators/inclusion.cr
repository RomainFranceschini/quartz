module HasIncludes
  abstract def includes?(value)
end

class String
  include HasIncludes
end

struct Range(B, E)
  include HasIncludes
end

# module Enumerable(T)
#   include HasIncludes
# end

module Quartz
  module Validators
    class InclusionValidator < EachValidator
      getter delimiter : HasIncludes

      def initialize(*attributes, **kwargs)
        super(*attributes, **kwargs)
        if (delimiter = (kwargs[:in]? || kwargs[:within])) && delimiter.responds_to?(:includes?) && delimiter.is_a?(HasIncludes)
          @delimiter = delimiter
        end
      end

      def validate_each(model, attribute, value)
        unless @delimiter.includes?(value)
          model.errors.add(attribute, "must be included in #{@delimiter}")
        end
      end
    end
  end
end
