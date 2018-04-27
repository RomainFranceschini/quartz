require "../spec_helper"

private module GeneratorScenario
  class GenTestError < Exception; end

  class TestGen < Quartz::AtomicModel
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0
    getter time : TimePoint = TimePoint.new

    def output
      @output_calls += 1
    end

    def time_advance
      Duration.new(1)
    end

    def internal_transition
      @internal_calls += 1
      @time = @time.advance(by: @elapsed)

      raise GenTestError.new unless @elapsed == Duration.new(1)
      raise GenTestError.new unless @time.to_i == @internal_calls
    end
  end

  describe TestGen do
    describe "simulation" do
      it "calls ∂int and lambda" do
        gen = TestGen.new(:testgen)
        sim = Quartz::Simulation.new(gen, duration: Duration.new(10))

        sim.each_with_index { |e, i|
          gen.output_calls.should eq(i + 1)
          gen.internal_calls.should eq(i + 1)
          gen.time.to_i.should eq(i + 1)
        }

        gen.output_calls.should eq(9)
        gen.internal_calls.should eq(9)
        gen.time.to_i.should eq(9)
      end
    end
  end
end
