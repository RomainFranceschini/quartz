module Quartz
  module Verifiers
    class PresenceChecker < EachChecker
      def check_each(model, attribute, value)
        if value.nil?
          model.errors.add(attribute, "can't be nil")
        elsif value.responds_to?(:empty?)
          model.errors.add(attribute, "can't be empty") if value.empty?
        elsif value.is_a?(Bool)
          model.errors.add(attribute, "can't be false") unless value
        elsif value.responds_to?(:nan?)
          model.errors.add(attribute, "can't be NAN") if value.nan?
        elsif value.responds_to?(:size)
          model.errors.add(attribute, "size can't be 0") if value.size == 0
        end
      end
    end
  end
end
