require "../src/quartz"
require "csv"

module DEVStone
  class Model < Quartz::AtomicModel
    input :in1, :in2
    output :out1, :out2

    state phase : Symbol = :idle

    def time_advance : Quartz::Duration
      if phase == :idle
        Quartz::Duration::INFINITY
      else
        Quartz::Duration.new(RND.rand(0i64..Quartz::Duration::MULTIPLIER_MAX))
      end
    end

    def external_transition(messages)
      state.phase = :active
    end

    def internal_transition
      state.phase = :idle
    end

    def output
      each_output_port { |port| post(name, port) }
    end
  end

  class Generator < Quartz::AtomicModel
    output :out

    state phase : Symbol = :init

    def time_advance : Quartz::Duration
      if phase == :init
        Quartz.duration(1)
      else
        Quartz.duration(5)
      end
    end

    def output
      post(name, :out)
    end

    def internal_transition
      state.phase = :generate if phase == :init
    end

    def external_transition(bag)
    end
  end

  class Collector < Quartz::AtomicModel
    include Quartz::PassiveBehavior
    input :in
  end

  class CoupledRecursion < Quartz::CoupledModel
    input :in
    output :out

    def initialize(name, coupling_type, width, level, depth)
      super(name)

      if level == depth - 1 # deepest level
        model = Model.new("am_l#{level + 1}n1")
        self << model
        attach_input(:in, to: :in1, of: model)
        attach_output(:out1, of: model, to: :out)
      else # upper levels
        model = CoupledRecursion.new("cm_#{level + 1}", coupling_type, width, level + 1, depth)
        self << model
        attach_input(:in, to: :in, of: model)
        attach_output(:out, of: model, to: :out)

        models = [] of Model
        (width - 1).times do |i|
          atomic = Model.new("am_l#{level + 1}n#{i + 1}")
          self << atomic
          models << atomic
          attach_input(:in, to: :in1, of: atomic)
        end

        if coupling_type > 1
          (width - 2).times do |i|
            attach(:out1, to: :in1, between: models[i], and: models[i + 1])
          end
        end
      end
    end
  end

  class DEVStone < Quartz::CoupledModel
    def initialize(coupling_type, width, depth)
      super(:devstone)
      self << Generator.new(:generator)
      self << CoupledRecursion.new(:cm_0, coupling_type, width, 0, depth)
      self << Collector.new(:collector)

      attach(:out, to: :in, between: :generator, and: :cm_0)
      attach(:out, to: :in, between: :cm_0, and: :collector)
    end
  end
end

RND = Random.new(684321)
iterations = 10
width = 100
depths = {5}
duration = Quartz::Duration.new(1000)
depths = (5..30).step(5)

Quartz.set_no_log_backend

result = CSV.build do |csv|
  csv.row "width", "depth", "flattened", "trial", "elapsed time (s)"

  depths.each do |depth|
    {true, false}.each do |maintain_hierarchy|
      iterations.times do |i|
        GC.collect

        root = DEVStone::DEVStone.new(2, width, depth)
        simulation = Quartz::Simulation.new(
          root,
          duration: duration,
          maintain_hierarchy: maintain_hierarchy,
          scheduler: :binary_heap,
        )

        csv.row do |row|
          row.concat(width, depth, !maintain_hierarchy, i)
          simulation.simulate
          row << simulation.elapsed_secs
          pp width, depth, !maintain_hierarchy, i, simulation.elapsed_secs
        end

        simulation.restart
      end
    end
  end
end

File.write("bm_flattening_devstone_res.csv", result)
