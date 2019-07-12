require "../spec_helper"

private module TransducerScenario
  class Gen < Quartz::AtomicModel
    output chars

    state_var cursor : Int32 = 0
    state_var full_msg : String = "hello world"

    def external_transition(bag)
    end

    def confluent_transition(bag)
    end

    def output
      post @full_msg[@cursor], on: :chars
    end

    def internal_transition
      @cursor += 1
    end

    def time_advance
      if @cursor < @full_msg.size
        Duration.new(1)
      else
        Duration::INFINITY
      end
    end
  end

  class ColChars < Quartz::AtomicModel
    include Quartz::PassiveBehavior

    input chars

    state_var chars : Array(Char) = Array(Char).new

    def external_transition(bag)
      chars << bag[input_port(:chars)].first.as_c
    end
  end

  class ColInts < Quartz::AtomicModel
    include Quartz::PassiveBehavior

    input ints

    state_var ints : Array(Int32) = Array(Int32).new

    def external_transition(bag)
      ints << bag[input_port(:ints)].first.as_i
    end
  end

  describe "Coupling transducers" do
    it "maps values if transducers are set" do
      model = Quartz::CoupledModel.new(:root)
      gen = Gen.new(:gen)
      col_chars = ColChars.new(:col_chars)
      col_upcase_chars = ColChars.new(:col_upcase_chars)
      col_ints = ColInts.new(:col_ints)
      model << gen << col_chars << col_upcase_chars << col_ints
      model.attach(gen.output_port(:chars), to: col_chars.input_port(:chars))
      model.attach(gen.output_port(:chars), to: col_upcase_chars.input_port(:chars)) { |bag| bag.map { |any| Quartz::Any.new(any.as_c.upcase) } }
      model.attach(gen.output_port(:chars), to: col_ints.input_port(:ints)) { |bag| bag.map { |any| Quartz::Any.new(any.as_c.ord) } }

      sim = Quartz::Simulation.new(model, loggers: Loggers.new(false))
      sim.simulate

      col_chars.chars.should eq("hello world".chars)
      col_upcase_chars.chars.should eq("HELLO WORLD".chars)
      col_ints.ints.should eq("hello world".chars.map &.ord)
    end
  end
end
