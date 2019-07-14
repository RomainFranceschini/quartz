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

    it "are composed sequentially after flattening" do
      model = Quartz::CoupledModel.new(:root)

      gen = Gen.new(:gen)
      model << gen

      char_collectors = Quartz::CoupledModel.new(:char_collectors)
      char_collectors.add_input_port(:chars)
      col_chars = ColChars.new(:col_chars)
      col_upcase_chars = ColChars.new(:col_upcase_chars)
      char_collectors << col_chars << col_upcase_chars
      char_collectors.attach(char_collectors.input_port(:chars), to: col_chars.input_port(:chars))
      char_collectors.attach(char_collectors.input_port(:chars), to: col_upcase_chars.input_port(:chars)) { |bag|
        bag.map { |any| Quartz::Any.new(any.as_c.upcase) }
      }
      model << char_collectors

      int_collectors = Quartz::CoupledModel.new(:int_collectors)
      int_collectors.add_input_port(:ints)
      col_ints = ColInts.new(:col_ints)
      col_upcase_ints = ColInts.new(:col_upcase_ints)
      int_collectors << col_ints << col_upcase_ints
      int_collectors.attach(int_collectors.input_port(:ints), to: col_ints.input_port(:ints))
      int_collectors.attach(int_collectors.input_port(:ints), to: col_upcase_ints.input_port(:ints)) { |bag|
        bag.map { |any| Quartz::Any.new(any.as_i.chr.upcase.ord) }
      }
      model << int_collectors

      model.attach(gen.output_port(:chars), to: char_collectors.input_port(:chars))
      model.attach(gen.output_port(:chars), to: int_collectors.input_port(:ints)) { |bag| bag.map { |any| Quartz::Any.new(any.as_c.ord) } }

      sim = Quartz::Simulation.new(model, loggers: Loggers.new(false), maintain_hierarchy: false)
      sim.simulate
      col_chars.chars.should eq("hello world".chars)
      col_upcase_chars.chars.should eq("HELLO WORLD".chars)
      col_ints.ints.should eq("hello world".chars.map &.ord)
      col_upcase_ints.ints.should eq("HELLO WORLD".chars.map &.ord)
    end
  end
end
