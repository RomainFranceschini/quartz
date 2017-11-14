module Quartz
  module Models
    module Generators
      class SinusGenerator < Quartz::AtomicModel
        state_var amplitude : Float64 = 1.0
        state_var frequency : Float64 = 50.0
        state_var phase : Float64 = 0.0
        state_var step : Int32 = 20
        state_var qss_order : Int8 = 2i8
        state_var pulsation : Float64 { 2.0 * Math::PI * frequency }

        @sigma = VirtualTime(Float64).new(0.0)

        def internal_transition
          @sigma = VirtualTime(Float64).new(1.0 / @frequency / @step)
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
