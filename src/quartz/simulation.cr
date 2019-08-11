module Quartz
  # This class represent the interface to the simulation
  class Simulation
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
    getter status : Status = Status::Ready
    getter virtual_time : TimePoint = TimePoint.new(0)
    getter loggers : Loggers
    getter notifier : Hooks::Notifier

    @final_vtime : TimePoint?
    @scheduler : Symbol
    @processor : Simulable?
    @start_time : Time::Span?
    @final_time : Time::Span?
    @run_validations : Bool
    @model : CoupledModel
    @time_next : Duration = Duration.new(0)
    @termination_condition : Proc(TimePoint, CoupledModel, Bool)

    delegate ready?, to: @status
    delegate initialized?, to: @status
    delegate running?, to: @status
    delegate done?, to: @status
    delegate aborted?, to: @status

    def initialize(model : Model, *,
                   @scheduler : Symbol = :binary_heap,
                   maintain_hierarchy : Bool = true,
                   duration : (Duration | TimePoint) = Duration::INFINITY,
                   @run_validations : Bool = false,
                   @notifier : Hooks::Notifier = Hooks::Notifier.new,
                   @loggers : Loggers = Loggers.new(true))
      @final_vtime = case duration
                     when Duration
                       duration.infinite? ? nil : TimePoint.new(duration.multiplier, duration.precision)
                     when TimePoint
                       duration
                     end

      @termination_condition = if ftime = @final_vtime
                                 ->(vtime : TimePoint, model : CoupledModel) { vtime > ftime.not_nil! }
                               else
                                 ->(vtime : TimePoint, model : CoupledModel) { false }
                               end

      @model = case model
               when CoupledModel
                 model
               else
                 CoupledModel.new(:root_coupled_model) << model
               end

      unless maintain_hierarchy
        @loggers.timing("Modeling tree flattening") {
          @model.accept(DirectConnectionVisitor.new(@model))
        }
      end
    end

    # Set the termination condition
    def termination_condition(&block : TimePoint, CoupledModel -> Bool)
      @termination_condition = block
    end

    @[AlwaysInline]
    protected def processor
      @processor ||= begin
        @loggers.timing("Processor allocation") do
          visitor = ProcessorAllocator.new(self, @model)
          model.accept(visitor)
          visitor.simulable
        end
      end
    end

    def inspect(io)
      io << "<" << self.class.name << ": status=" << status.to_s(io)
      io << ", time=" << virtual_time.to_s(io)
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
        elsif child.responds_to?(:transition_stats)
          stats[child.model.name] = child.transition_stats.to_h
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
        @loggers.info "Aborting simulation."
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
        @loggers.info "Cannot restart, the simulation is currently running."
      end
    end

    private def begin_simulation
      @start_time = Time.monotonic
      @status = Status::Running
      @loggers.info "Beginning simulation"
      @notifier.notify(Hooks::PRE_SIMULATION)
    end

    private def end_simulation
      @final_time = Time.monotonic
      @status = Status::Done

      if @loggers.any_logger?
        @loggers.info "Simulation ended after #{elapsed_secs} secs."
        if @loggers.any_debug?
          str = String.build(512) do |str|
            str << "Transition stats : {\n"
            transition_stats.each do |k, v|
              str << "    #{k} => #{v}\n"
            end
            str << "}\n"
          end
          @loggers.debug str
          @loggers.debug "Running post simulation hook"
        end
      end
      @notifier.notify(Hooks::POST_SIMULATION)
    end

    def initialize_simulation
      if ready?
        begin_simulation
        @notifier.notify(Hooks::PRE_INIT)
        @loggers.timing("Simulation initialization") do
          @time_next = processor.initialize_state(@virtual_time)
        end
        @status = Status::Initialized
        @notifier.notify(Hooks::POST_INIT)
      else
        @loggers.info "Cannot initialize simulation while it is running or terminated."
      end
    end

    def step : Duration?
      case @status
      when Status::Ready
        initialize_simulation
        @time_next
      when Status::Initialized, Status::Running
        processor.advance by: @time_next
        if @termination_condition.call(@virtual_time, @model)
          end_simulation
          return nil
        end

        if @loggers.any_debug?
          @loggers.debug("Tick at #{virtual_time}, #{Time.monotonic - @start_time.not_nil!} secs elapsed.")
        end

        @time_next = processor.step(@time_next)

        end_simulation if @time_next.infinite?

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
          break if @termination_condition.call(@virtual_time, @model)

          if @loggers.any_debug?
            @loggers.debug("Tick at: #{virtual_time}, #{Time.monotonic - @start_time.not_nil!} secs elapsed.")
          end
          @time_next = processor.step(@time_next)
          break if @time_next.infinite?
        end
        end_simulation
      when Status::Running
        @loggers.error "Simulation already started at #{@start_time} and is currently running."
      when Status::Done, Status::Aborted
        @loggers.error "Simulation is terminated."
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
          break if @termination_condition.call(@virtual_time, @model)

          if @loggers.any_debug?
            @loggers.debug("Tick at: #{virtual_time}, #{Time.monotonic - @start_time.not_nil!} secs elapsed.")
          end
          @time_next = processor.step(@time_next)
          break if @time_next.infinite?
          yield(@time_next)
        end
        end_simulation
      when Status::Running
        @loggers.error "Simulation already started at #{@start_time} and is currently running."
      when Status::Done, Status::Aborted
        @loggers.error "Simulation is terminated."
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
