module Quartz
  # This class represent the interface to the simulation
  class Simulation
    include Logging
    include Enumerable(SimulationTime)
    include Iterable(SimulationTime)

    # Represents the current simulation status.
    enum Status
      Ready,
      Initialized,
      Running,
      Done,
      Aborted
    end

    getter processor, model, start_time, final_time, time
    getter duration
    getter status

    @status : Status
    @time : SimulationTime
    @scheduler : Symbol
    @processor : RootCoordinator?
    @start_time : Time?
    @final_time : Time?
    @run_validations : Bool
    @model : CoupledModel

    delegate ready?, to: @status
    delegate initialized?, to: @status
    delegate running?, to: @status
    delegate done?, to: @status
    delegate aborted?, to: @status

    def initialize(model : Model, *,
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
      @status = Status::Ready

      unless maintain_hierarchy
        Quartz.timing("Modeling tree flattening") {
          @model.accept(DirectConnectionVisitor.new(@model))
        }
      end
    end

    @[AlwaysInline]
    protected def processor
      @processor ||= begin
        Quartz.timing("Processor allocation") do
          visitor = ProcessorAllocator.new(self, @model)
          model.accept(visitor)
          visitor.root_coordinator
        end
      end
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

    def percentage
      case @status
      when Status::Ready, Status::Initialized
        0.0 * 100
      when Status::Done
        1.0 * 100
      when Status::Running, Status::Aborted
        if @time > @duration
          1.0 * 100
        else
          @time.to_f / @duration.to_f * 100
        end
      end
    end

    def elapsed_secs
      case @status
      when Status::Ready, Status::Initialized
        0.0
      when Status::Done, Status::Aborted
        @final_time.not_nil! - @start_time.not_nil!
      when Status::Running
        Time.now - @start_time.not_nil!
      end
    end

    # Returns the number of transitions per model along with the total
    def transition_stats
      stats = {} of Name => Hash(Symbol, UInt32)
      hierarchy = self.processor.children.dup
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
      stats.values.each { |h| h.each { |k, v| total[k] += v } }
      stats[:TOTAL] = total
      stats
    end

    # Abort the currently running or initialized simulation. Goes to an
    # aborted state.
    def abort
      if running? || initialized?
        info "Aborting simulation."
        @time = @duration
        @final_time = Time.now
        @status = Status::Aborted
      end
    end

    # Restart a terminated simulation (either done or aborted) and goes to a
    # ready state.
    def restart
      case @status
      when Status::Done, Status::Aborted
        @time = 0
        @start_time = nil
        @final_time = nil
        @status = Status::Ready
      when Status::Running, Status::Initialized
        info "Cannot restart, the simulation is currently running."
      end
    end

    private def begin_simulation
      @start_time = Time.now
      @status = Status::Running
      info "Beginning simulation with duration: #{@duration}"
      Hooks.notifier.notify(:before_simulation_hook)
    end

    private def end_simulation
      @final_time = Time.now
      @status = Status::Done

      if logger = Quartz.logger?
        logger.info "Simulation ended after #{elapsed_secs} secs."
        if logger.debug?
          str = String.build(512) do |str|
            str << "Transition stats : {\n"
            transition_stats.each do |k, v|
              str << "    #{k} => #{v}\n"
            end
            str << "}\n"
          end
          logger.debug str
          logger.debug "Running post simulation hook"
        end
      end
      Hooks.notifier.notify(:after_simulation_hook)
    end

    def initialize_simulation
      if ready?
        begin_simulation
        Hooks.notifier.notify(:before_simulation_initialization_hook)
        Quartz.timing("Simulation initialization") do
          @time = self.processor.initialize_state(@time)
        end
        @status = Status::Initialized
        Hooks.notifier.notify(:after_simulation_initialization_hook)
      else
        info "Cannot initialize simulation while it is running or terminated."
      end
    end

    def step : SimulationTime?
      case @status
      when Status::Ready
        initialize_simulation
        @time
      when Status::Initialized, Status::Running
        if (logger = Quartz.logger?) && logger.debug?
          logger.debug("Tick at #{@time}, #{Time.now - @start_time.not_nil!} secs elapsed.")
        end
        @time = processor.step(@time)
        end_simulation if @time >= @duration
        @time
      else
        nil
      end
    end

    # TODO error hook
    def simulate
      case @status
      when Status::Ready, Status::Initialized
        initialize_simulation unless initialized?

        begin_simulation
        while @time < @duration
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("Tick at: #{@time}, #{Time.now - @start_time.not_nil!} secs elapsed.")
          end
          @time = processor.step(@time)
        end
        end_simulation
      when Status::Running
        error "Simulation already started at #{@start_time} and is currently running."
      when Status::Done, Status::Aborted
        error "Simulation is terminated."
      end
      self
    end

    def each
      StepIterator.new(self)
    end

    def each
      case @status
      when Status::Ready, Status::Initialized
        initialize_simulation unless initialized?

        begin_simulation
        while @time < @duration
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("Tick at: #{@time}, #{Time.now - @start_time.not_nil!} secs elapsed.")
          end
          @time = processor.step(@time)
          yield(self)
        end
        end_simulation
      when Status::Running
        error "Simulation already started at #{@start_time} and is currently running."
      when Status::Done, Status::Aborted
        error "Simulation is terminated."
      end
      self
    end

    class StepIterator
      include Iterator(SimulationTime)

      def initialize(@simulation : Simulation)
      end

      def next
        case @simulation.status
        when Simulation::Status::Done, Simulation::Status::Aborted
          stop
        when Simulation::Status::Ready
          @simulation.initialize_simulation
        when Simulation::Status::Initialized, Simulation::Status::Running
          @simulation.step.not_nil!
        end
      end

      def rewind
        @simulation.abort if @simulation.running?
        @simulation.restart
        self
      end
    end

    def generate_graph(path = "model_hierarchy.dot")
      path = "#{path}.dot" if File.extname(path).empty?
      file = File.new(path, "w+")
      generate_graph(file)
      file.close
    end

    def generate_graph(io : IO)
      DotVisitor.new(@model, io).to_graph
    end
  end
end
