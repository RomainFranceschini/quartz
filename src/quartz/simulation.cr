module Quartz
  # This class represent the interface to the simulation
  class Simulation
    include Logging
    include Enumerable(Duration)
    include Iterable(Duration)

    # Represents the current simulation status.
    enum Status
      Ready
      Initialized
      Running
      Done
      Aborted
    end

    getter processor, model, start_time, final_time
    getter status : Status
    getter virtual_time : TimePoint
    getter notifier : Hooks::Notifier

    @status : Status
    @final_vtime : TimePoint?
    @scheduler : Symbol
    @processor : Simulable?
    @start_time : Time::Span?
    @final_time : Time::Span?
    @run_validations : Bool
    @model : CoupledModel
    @time_next : Duration

    delegate ready?, to: @status
    delegate initialized?, to: @status
    delegate running?, to: @status
    delegate done?, to: @status
    delegate aborted?, to: @status

    def initialize(model : Model, *,
                   scheduler : Symbol = :binary_heap,
                   maintain_hierarchy : Bool = true,
                   duration : Duration = Duration::INFINITY,
                   run_validations : Bool = false)
      @final_vtime = if duration.infinite?
                       nil
                     else
                       TimePoint.new(duration.multiplier, duration.precision)
                     end

      @virtual_time = TimePoint.new(0)
      @notifier = Hooks::Notifier.new

      @model = case model
               when AtomicModel, MultiComponent::Model
                 CoupledModel.new(:root_coupled_model) << model
               else
                 model
               end

      @time_next = Duration.new(0)
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
          visitor.simulable
        end
      end
    end

    def inspect(io)
      io << "<" << self.class.name << ": status=" << status.to_s(io)
      io << ", time=" << virtual_time.to_s(io)
      io << ", final_time=" << @final_vtime ? @final_vtime.to_s(io) : "INFINITY"
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
        if final = @final_vtime
          if virtual_time > final
            1.0 * 100
          else
            (virtual_time.to_i64 - final) / (Duration.new(final.to_i64, final.precision)) * 100
          end
        else
          Float::NAN
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
        Time.monotonic - @start_time.not_nil!
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
        @notifier.notify(Hooks::PRE_ABORT)
        info "Aborting simulation."
        @final_time = Time.monotonic
        @status = Status::Aborted
        @notifier.notify(Hooks::POST_ABORT)
      end
    end

    # Restart a terminated simulation (either done or aborted) and goes to a
    # ready state.
    def restart
      case @status
      when Status::Done, Status::Aborted
        @notifier.notify(Hooks::PRE_RESTART)
        @start_time = nil
        @final_time = nil
        @virtual_time = TimePoint.new
        @status = Status::Ready
        @notifier.notify(Hooks::POST_RESTART)
      when Status::Running, Status::Initialized
        info "Cannot restart, the simulation is currently running."
      end
    end

    private def begin_simulation
      @start_time = Time.monotonic
      @status = Status::Running
      info "Beginning simulation until time point: #{@final_vtime ? @final_vtime : "INFINITY"}"
      @notifier.notify(Hooks::PRE_SIMULATION)
    end

    private def end_simulation
      @final_time = Time.monotonic
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
      @notifier.notify(Hooks::POST_SIMULATION)
    end

    def initialize_simulation
      if ready?
        begin_simulation
        @notifier.notify(Hooks::PRE_INIT)
        Quartz.timing("Simulation initialization") do
          @time_next = processor.initialize_state(@virtual_time)
        end
        @status = Status::Initialized
        @notifier.notify(Hooks::POST_INIT)
      else
        info "Cannot initialize simulation while it is running or terminated."
      end
    end

    def step : Duration?
      case @status
      when Status::Ready
        initialize_simulation
        @time_next
      when Status::Initialized, Status::Running
        processor.advance by: @time_next
        if (logger = Quartz.logger?) && logger.debug?
          logger.debug("Tick at #{virtual_time}, #{Time.monotonic - @start_time.not_nil!} secs elapsed.")
        end
        @time_next = processor.step(@time_next)
        if @time_next.infinite?
          end_simulation
        elsif final = @final_vtime
          end_simulation if @time_next >= (final - virtual_time)
        end
        @time_next
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
        loop do
          processor.advance by: @time_next
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("Tick at: #{virtual_time}, #{Time.monotonic - @start_time.not_nil!} secs elapsed.")
          end
          @time_next = processor.step(@time_next)
          if @time_next.infinite?
            break
          elsif final = @final_vtime
            break if @time_next >= (final - virtual_time)
          end
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
        loop do
          processor.advance by: @time_next
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug("Tick at: #{virtual_time}, #{Time.monotonic - @start_time.not_nil!} secs elapsed.")
          end
          @time_next = processor.step(@time_next)
          if @time_next.infinite?
            break
          elsif final = @final_vtime
            break if @time_next >= (final - virtual_time)
          end
          yield(@time_next)
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
      include Iterator(Duration)

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
