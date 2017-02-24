module Quartz
  # This class represent the interface to the simulation
  class Simulation
    include Logging
    include Enumerable(SimulationTime)

    getter processor, model, start_time, final_time, time
    getter duration

    @time : SimulationTime
    @scheduler : Symbol
    @processor : Coordinator
    @start_time : Time?
    @final_time : Time?
    @run_validations : Bool

    def initialize(
                   model : Model, *,
                   scheduler : Symbol = :calendar_queue,
                   maintain_hierarchy : Bool = true,
                   duration : SimulationTime = Quartz::INFINITY,
                   run_validations : Bool = false)
      @time = 0

      @model = case model
      when AtomicModel, MultiComponent::Model
        CoupledModel.new(:root_coupled_model) << model
      else
        model
      end

      @duration = duration
      @scheduler = scheduler
      @run_validations = run_validations

      # TODO check direct_connect correctness
      unless maintain_hierarchy
        time = Time.now
        direct_connect!
        if logger = Quartz.logger?
          logger.info "  * Flattened modeling tree in #{Time.now - time} secs"
        end
      end

      time = Time.now
      @processor = allocate_processors
      info "  * Allocated processors in #{Time.now - time} secs"
    end

    def inspect(io)
      io << "<" << self.class.name << ": status=" << status.to_s(io)
      io << ", time=" << @time.to_s(io)
      io << ", duration=" << @duration.to_s(io)
      nil
    end

    # Returns the default scheduler to use.
    def default_scheduler
      @scheduler
    end

    # Whether `Quartz::Validations` will be run during simulation.
    def run_validations?
      @run_validations
    end

    # Returns *true* if the simulation is done, *false* otherwise.
    def done?
      @time >= @duration
    end

    # Returns *true* if the simulation is currently running,
    # *false* otherwise.
    def running?
      @start_time != nil && !done?
    end

    # Returns *true* if the simulation is waiting to be started,
    # *false* otherwise.
    def waiting?
      @start_time == nil
    end

    # Returns the simulation status: *waiting*, *running* or
    # *done*.
    def status
      if waiting?
        :waiting
      elsif running?
        :running
      elsif done?
        :done
      end
    end

    def percentage
      case status
      when :waiting then 0.0 * 100
      when :done    then 1.0 * 100
      when :running
        if @time > @duration
          1.0 * 100
        else
          @time.to_f / @duration.to_f * 100
        end
      end
    end

    def elapsed_secs
      case status
      when :waiting
        0.0
      when :done
        @final_time.not_nil! - @start_time.not_nil!
      when :running
        Time.now - @start_time.not_nil!
      end
    end

    # Returns the number of transitions per model along with the total
    def transition_stats
      stats = {} of Name => Hash(Symbol, UInt32)
      hierarchy = @processor.children.dup
      hierarchy.each do |child|
        if child.is_a?(Coordinator)
          coordinator = child.as(Coordinator)
          hierarchy.concat(coordinator.children)
        else
          simulator = child.as(Simulator)
          stats[child.model.name] = simulator.transition_stats.to_h
        end
      end
      total = Hash(Symbol, UInt32).new { 0_u32 }
      stats.values.each { |h| h.each { |k, v| total[k] += v }}
      stats[:TOTAL] = total
      stats
    end

    def abort
      if running?
        info "Aborting simulation."
        @time = @duration
        @final_time = Time.now
      end
    end

    def restart
      case status
      when :done
        @time = 0
        @start_time = nil
        @final_time = nil
      when :running
        info "Cannot restart, the simulation is currently running."
      end
    end

    private def begin_simulation
      @start_time = Time.now
      info "*** Beginning simulation at #{@start_time} with duration: #{@duration}"
      Hooks.notifier.notify(:before_simulation_hook)
    end

    private def end_simulation
      @final_time = Time.now

      if logger = Quartz.logger?
        logger.info "*** Simulation ended at #{@final_time} after #{elapsed_secs} secs."
        if logger.debug?
          str = String.build(512) do |str|
            str << "* Transition stats : {\n"
            transition_stats.each do |k, v|
              str << "    #{k} => #{v}\n"
            end
            str << "* }\n"
            str << "* Running post simulation hook"
          end
          logger.debug(str)
        end
      end
      Hooks.notifier.notify(:after_simulation_hook)
    end

    private def initialize_simulation
      Hooks.notifier.notify(:before_simulation_initialization_hook)
      @time = @processor.as(Simulable).initialize_state(@time)
      Hooks.notifier.notify(:after_simulation_initialization_hook)
    end

    def step : SimulationTime?
      simulable = @processor.as(Simulable)
      if waiting?
        initialize_simulation
        begin_simulation
        @time
      elsif running?
        if (logger = Quartz.logger?) && logger.debug?
          logger.debug("* Tick at: #{@time}, #{Time.now - @start_time.not_nil!} secs elapsed")
        end
        @time = simulable.step(@time)
        end_simulation if done?
        @time
      else
        nil
      end
    end

    # TODO error hook
    def simulate
      if waiting?
        simulable = @processor.as(Simulable)
        initialize_simulation
        begin_simulation
        while @time < @duration
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("* Tick at: #{@time}, #{Time.now - @start_time.not_nil!} secs elapsed")
          end
          @time = simulable.step(@time)
        end
        end_simulation
      elsif logger = Quartz.logger?
        if running?
          logger.error "The simulation already started at #{@start_time} and is currently running."
        else
          logger.error "The simulation is already done. Started at #{@start_time} and finished at #{@final_time} in #{elapsed_secs} secs."
        end
      end
      self
    end

    def each
      StepIterator.new(self)
    end

    def each
      if waiting?
        simulable = @processor.as(Simulable)
        initialize_simulation
        begin_simulation
        while @time < @duration
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("* Tick at: #{@time}, #{Time.now - @start_time.not_nil!} secs elapsed")
          end
          @time = simulable.step(@time)
          yield(self)
        end
        end_simulation
      elsif logger = Quartz.logger?
        if running?
          logger.error "The simulation already started at #{@start_time} and is currently running."
        else
          logger.error "The simulation is already done. Started at #{@start_time} and finished at #{@final_time} in #{elapsed_secs} secs."
        end
        nil
      end
    end

    class StepIterator
      include Iterator(SimulationTime)

      def initialize(@simulation : Simulation)
      end

      def next
        if @simulation.done?
          stop
        else
          @simulation.step.not_nil!
        end
      end

      def rewind
        @simulation.abort if @simulation.running?
        @simulation.restart
        self
      end
    end

    def generate_graph(path="model_hierarchy.dot")
      path = "#{path}.dot" if File.extname(path).empty?
      file = File.new(path, "w+")
      file.puts "digraph"
      file.puts '{'
      file.puts "compound = true;"
      file.puts "rankdir = LR;"
      file.puts "node [shape = box];"

      fill_graph(file, @model.as(CoupledModel))

      file.puts '}'
      file.close
    end

    private def fill_graph(graph, cm : CoupledModel)
      cm.each_child do |model|
        name = model.to_s
        if model.is_a?(CoupledModel)
          graph.puts "subgraph \"cluster_#{name}\""
          graph.puts '{'
          graph.puts "label = \"#{name}\";"
          fill_graph(graph, model.as(CoupledModel))
          model.each_internal_coupling do |src, dst|
            if src.host.is_a?(AtomicModel) && dst.host.is_a?(AtomicModel)
              graph.puts "\"#{src.host.name.to_s}\" -> \"#{dst.host.name.to_s}\" [label=\"#{src.name.to_s} → #{dst.name.to_s}\"];"
            end
          end
          graph.puts "};"
        else
          graph.puts "\"#{name}\" [style=filled];"
        end
      end

      find_direct_couplings(cm) do |src, dst|
        graph.puts "\"#{src.host.name.to_s}\" -> \"#{dst.host.name.to_s}\" [label=\"#{src.name.to_s} → #{dst.name.to_s}\"];"
      end if cm == @model
    end

    def allocate_processors(coupled = @model)
      is_root = coupled == @model
      processor = ProcessorFactory.processor_for(coupled, self, is_root).as(Coordinator)

      coupled.as(CoupledModel).each_child do |model|
        processor << if model.is_a?(CoupledModel)
          allocate_processors(model)
        else
          ProcessorFactory.processor_for(model, self)
        end
      end

      processor
    end

    # TODO don't alter original hierarchy
    private def direct_connect!
      models = @model.as(CoupledModel).each_child.to_a
      children_list = [] of Model
      new_internal_couplings = Hash(Port,Array(Port)).new { |h,k| h[k] = [] of Port }

      i = 0
      while i < models.size
        model = models[i]
        if model.is_a?(CoupledModel)
          # get internal couplings between atomics that we can reuse as-is in the root model
          coupled = model.as(CoupledModel)
          coupled.each_internal_coupling do |src, dst|
            if src.host.is_a?(AtomicModel) && dst.host.is_a?(AtomicModel)
              new_internal_couplings[src] << dst
            end
          end
          coupled.each_child { |c| models << c }
        else
          children_list << model
        end
        i+=1
      end

      cm = @model.as(CoupledModel)
      cm.each_child.each { |c| cm.remove_child(c) }
      children_list.each { |c| cm << c  }

      find_direct_couplings(cm) do |src, dst|
        new_internal_couplings[src] << dst
      end

      internal_couplings = cm.internal_couplings.clear
      internal_couplings.merge!(new_internal_couplings)
    end

    private def find_direct_couplings(cm : CoupledModel, &block : Port, Port -> )
      couplings = [] of {Port, Port}
      cm.each_coupling { |s,d| couplings << {s,d} }

      i = 0
      while i < couplings.size
        osrc, odst = couplings[i]
        if osrc.host.is_a?(AtomicModel) && odst.host.is_a?(AtomicModel)
          yield(osrc, odst) # found direct coupling
        elsif osrc.host.is_a?(CoupledModel) # eic
          route = [{osrc, odst}]
          j = 0
          while j < route.size
            rsrc, _ = route[j]
            rsrc.host.as(CoupledModel).each_output_coupling_reverse(rsrc) do |src, dst|
              if src.host.is_a?(CoupledModel)
                route.push({src, dst})
              else
                couplings.push({src, odst})
              end
            end
            j += 1
          end
        elsif odst.host.is_a?(CoupledModel) # eoc
          route = [{osrc,odst}]
          j = 0
          while j < route.size
            _, rdst = route[j]
            rdst.host.as(CoupledModel).each_input_coupling(rdst) do |src,dst|
              if dst.host.is_a?(CoupledModel)
                route.push({src, dst})
              else
                couplings.push({osrc, dst})
              end
            end
            j += 1
          end
        end
        i += 1
      end
    end

  end
end
