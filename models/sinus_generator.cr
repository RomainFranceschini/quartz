module Quartz
  module Models
    module Generators
      class SinusGenerator < Quartz::AtomicModel

        @pulsation : Float32

        def initialize(name, @amplitude : Float = 1.0 , @frequency : Float = 50.0, @phase : Float = 0.0, @step : Int = 20, @qss_order : Int = 2)
          super(name)
          @pulsation = 2.0 * Math::PI * @frequency
          @sigma = 0
        end

        def internal_transition
          @sigma = 1.0 / @frequency / @step
        end

        def output
          value = case @qss_order
          when 1 then @amplitude * Math.sin(@pulsation * (self.time + @sigma) + @phase)
          when 2 then @amplitude * @pulsation * Math.cos(@pulsation * (self.time + @sigma) + @phase)
          when 3 then -@amplitude * (@pulsation ** 2) * Math.sin(@pulsation * (self.time + @sigma) + @phase) / 2
          end

          output_ports.each_key { |port| post(value, port) }
        end
      end
    end
  end
end
