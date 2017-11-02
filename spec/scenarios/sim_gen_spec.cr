require "../spec_helper"

private module GeneratorScenario

  class GenTestError < Exception; end

  class TestGen < Quartz::AtomicModel
    getter output_calls : Int32 = 0
    getter internal_calls : Int32 = 0

    def output
      @output_calls += 1
    end

    def time_advance
      1
    end

    def internal_transition
      @internal_calls += 1

      raise GenTestError.new unless @elapsed == 0
      raise GenTestError.new unless @time == @internal_calls
    end
  end

  describe TestGen do
    describe "simulation" do
      it "calls ∂int and lambda" do
        gen = TestGen.new(:testgen)
        sim = Quartz::Simulation.new(gen, duration: 10)

        sim.each_with_index { |e, i|
          gen.output_calls.should eq(i+1)
          gen.internal_calls.should eq(i+1)
          gen.time.should eq(i+1)
        }

        gen.output_calls.should eq(9)
        gen.internal_calls.should eq(9)
        gen.time.should eq(9)
      end
    end
  end
end
