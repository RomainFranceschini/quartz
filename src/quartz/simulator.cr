module Quartz
  # This class defines a PDEVS simulator.
  class Simulator < Processor
    @int_count : UInt32 = 0u32
    @ext_count : UInt32 = 0u32
    @con_count : UInt32 = 0u32
    @run_validations : Bool
    @loggers : Loggers

    def initialize(model : Model, simulation : Simulation)
      @run_validations = simulation.run_validations?
      @loggers = simulation.loggers
      super(model)
    end

    def transition_stats
      {
        internal:  @int_count,
        external:  @ext_count,
        confluent: @con_count,
      }
    end

    def initialize_processor(time : TimePoint) : {Duration, Duration}
      atomic = @model.as(AtomicModel)
      @int_count = @ext_count = @con_count = 0u32

      atomic.__initialize_state__(self)
      elapsed = atomic.elapsed
      planned_duration = atomic.time_advance.as(Duration)

      if @run_validations && atomic.invalid?(:initialization)
        if @loggers.any_logger?
          @loggers.error(String.build { |str|
            str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
            str << " (context: 'init', time: " << time << "). "
            str << "Errors: " << atomic.errors.full_messages
          })
        end
      end

      if @loggers.any_debug?
        @loggers.debug(String.build { |str|
          str << '\'' << atomic.name << "' initialized ("
          str << "elapsed: " << elapsed << ", time_next: " << planned_duration << ')'
        })
      end

      if atomic.count_observers > 0
        atomic.notify_observers(OBS_INFO_INIT_TRANSITION.merge({:time => time}))
      end

      {elapsed.fixed, planned_duration.fixed}
    rescue err : StrictVerificationFailed
      atomic = @model.as(AtomicModel)
      if @loggers.any_logger?
        @loggers.fatal(String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: 'init', time: " << time << "). "
          str << "Errors: " << atomic.errors.full_messages
        })
      end
      raise err
    end

    def collect_outputs(elapsed : Duration) : Hash(OutputPort, Array(Any))
      @model.as(AtomicModel).fetch_output!
    end

    def perform_transitions(time : TimePoint, elapsed : Duration, imminent : Bool = false) : Duration
      atomic = @model.as(AtomicModel)
      bag = @bag || EMPTY_BAG

      info = nil
      kind = nil
      atomic.elapsed = elapsed

      if imminent
        if bag.empty?
          @int_count += 1u32
          atomic.internal_transition
          info = OBS_INFO_INT_TRANSITION
          kind = :internal
        else
          @con_count += 1u32
          atomic.confluent_transition(bag)
          info = OBS_INFO_CON_TRANSITION
          kind = :confluent
        end
      elsif !imminent && !bag.empty?
        @ext_count += 1u32
        atomic.external_transition(bag)
        info = OBS_INFO_EXT_TRANSITION
        kind = :external
      else
        raise BadSynchronisationError.new("#{model.name} is unsynced (elapsed:#{elapsed}, bag size:#{bag.size}, time:#{time}).")
      end

      bag.clear
      planned_duration = atomic.time_advance.as(Duration)
      fixed_planned_duration = planned_duration.fixed_at(atomic.class.precision_level)
      if !planned_duration.infinite? && fixed_planned_duration.infinite?
        raise InvalidDurationError.new("#{model.name} planned duration cannot exceed #{Duration.new(Duration::MULTIPLIER_MAX, atomic.class.precision_level)} given its precision level.")
      elsif planned_duration.precision < atomic.class.precision_level
        raise InvalidDurationError.new("'#{atomic.name}': planned duration #{planned_duration} was coarsed to #{atomic.class.precision_level} due to the model precision level.")
      end

      if @loggers.any_debug?
        @loggers.debug(String.build { |str|
          str << '\'' << atomic.name << "': " << kind << " transition "
          str << "(elapsed: " << elapsed << ", time_next: " << fixed_planned_duration << ')'
        })
      end

      if @run_validations && atomic.invalid?(kind)
        if @loggers.any_logger?
          @loggers.error(String.build { |str|
            str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
            str << " (context: '" << kind << "')."
            str << "Errors: " << atomic.errors.full_messages
          })
        end
      end

      if atomic.count_observers > 0
        atomic.notify_observers(info.merge({:time => time, :elapsed => elapsed}))
      end

      fixed_planned_duration
    rescue err : StrictVerificationFailed
      atomic = @model.as(AtomicModel)
      if @loggers.any_logger?
        @loggers.fatal(String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: '" << kind << "')."
          str << "Errors: " << atomic.errors.full_messages
        })
      end
      raise err
    end
  end
end
