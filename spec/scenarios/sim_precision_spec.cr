require "../spec_helper"

private module PrecisionScenario
  class InvalidGenerator1 < Quartz::AtomicModel
    output :out

    precision micro
    @sigma = Quartz::Duration.new(0)

    def internal_transition
      @sigma = Quartz::Duration.new(1_000_000_000_000_000 - 1, Scale.new(0))
    end

    def output
      post nil, on: :out
    end
  end

  class InvalidGenerator2 < Quartz::AtomicModel
    output :out

    precision micro
    @sigma = Quartz::Duration.new(0)

    def internal_transition
      @sigma = Quartz::Duration.new(62345726354, Scale.new(-6))
    end

    def output
      post nil, on: :out
    end
  end

  class Generator < Quartz::AtomicModel
    output :out

    precision micro
    @sigma = Quartz::Duration.new(100, Quartz::Scale::MILLI)

    def output
      post nil, on: :out
    end
  end

  class FineCollector < Quartz::AtomicModel
    precision nano
    input :in
  end

  class RoughCollector < Quartz::AtomicModel
    precision tera
    input :in
  end

  describe "simulation" do
    it "raises when planned durations exceed maximum duration based on model precision" do
      m = InvalidGenerator1.new(:gen)
      sim = Quartz::Simulation.new(m)
      sim.initialize_simulation

      expect_raises Quartz::InvalidDurationError do
        sim.step
      end
    end

    it "raises when planned durations are below the model precision" do
      m = InvalidGenerator2.new(:gen)
      sim = Quartz::Simulation.new(m)
      sim.initialize_simulation

      expect_raises Quartz::InvalidDurationError do
        sim.step
      end
    end

    it "elapsed values are expressed in the model precision level" do
      c = Quartz::CoupledModel.new(:root)
      gen = Generator.new(:gen)
      col = FineCollector.new(:col)
      c << gen << col
      c.attach :out, to: :in, between: gen, and: col

      sim = Quartz::Simulation.new(c)
      sim.initialize_simulation

      sim.step # generator sends value collector receives value

      col.elapsed.precision.should eq(col.model_precision)
      col.elapsed.should eq(Duration.new(100_000_000, Scale::NANO))
    end

    it "elapsed values are rounded off to the model precision level" do
      c = Quartz::CoupledModel.new(:root)
      gen = Generator.new(:gen)
      col = RoughCollector.new(:col)
      c << gen << col
      c.attach :out, to: :in, between: gen, and: col

      sim = Quartz::Simulation.new(c)
      sim.initialize_simulation

      sim.step # generator sends value collector receives value

      col.elapsed.precision.should eq(col.model_precision)
      col.elapsed.should eq(Duration.new(0, Scale::TERA))
    end
  end
end
