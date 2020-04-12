module Quartz
  # This class defines a PDEVS simulator.
  class Simulator < Processor
    include Schedulable

    @int_count : UInt32 = 0u32
    @ext_count : UInt32 = 0u32
    @con_count : UInt32 = 0u32
    @run_validations : Bool

    def initialize(model : Model, simulation : Simulation)
      @run_validations = simulation.run_validations?
      super(model)
    end

    def transition_stats
      {
        internal:  @int_count,
        external:  @ext_count,
        confluent: @con_count,
      }
    end

    private def fixed_planned_duration(planned_duration : Duration, level : Scale) : Duration
      fixed_planned_duration = planned_duration.fixed_at(level)
      if !planned_duration.infinite? && fixed_planned_duration.infinite?
        raise InvalidDurationError.new("#{model.name} planned duration cannot exceed #{Duration.new(Duration::MULTIPLIER_MAX, level)} given its precision level.")
      elsif planned_duration.precision < level
        raise InvalidDurationError.new("'#{model.name}': planned duration #{planned_duration} was coarsed to #{level} due to the model precision level.")
      end
      fixed_planned_duration
    end

    def initialize_processor(time : TimePoint) : {Duration, Duration}
      atomic = @model.as(AtomicModel)
      @int_count = @ext_count = @con_count = 0u32

      atomic.__initialize_state__(self)
      elapsed = atomic.elapsed
      planned_duration = fixed_planned_duration(atomic.time_advance.as(Duration), atomic.class.precision_level)

      if @run_validations && atomic.invalid?(:initialization)
        Log.error {
          String.build { |str|
            str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
            str << " (context: 'init', time: " << time << "). "
            str << "Errors: " << atomic.errors.full_messages
          }
        }
      end

      Log.debug {
        String.build { |str|
          str << '\'' << atomic.name << "' initialized ("
          str << "elapsed: " << elapsed << ", time_next: " << planned_duration << ')'
        }
      }

      if atomic.count_observers > 0
        atomic.notify_observers(OBS_INFO_INIT_TRANSITION.merge({:time => time}))
      end

      {elapsed.fixed, planned_duration}
    rescue err : StrictVerificationFailed
      atomic = @model.as(AtomicModel)

      Log.fatal {
        String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: 'init', time: " << time << "). "
          str << "Errors: " << atomic.errors.full_messages
        }
      }

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
      planned_duration = fixed_planned_duration(atomic.time_advance.as(Duration), atomic.class.precision_level)

      Log.debug {
        String.build { |str|
          str << '\'' << atomic.name << "': " << kind << " transition "
          str << "(elapsed: " << elapsed << ", time_next: " << planned_duration << ')'
        }
      }

      if @run_validations && atomic.invalid?(kind)
        Log.error {
          String.build { |str|
            str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
            str << " (context: '" << kind << "')."
            str << "Errors: " << atomic.errors.full_messages
          }
        }
      end

      if atomic.count_observers > 0
        atomic.notify_observers(info.merge({:time => time, :elapsed => elapsed}))
      end

      planned_duration
    rescue err : StrictVerificationFailed
      atomic = @model.as(AtomicModel)

      Log.fatal {
        String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: '" << kind << "')."
          str << "Errors: " << atomic.errors.full_messages
        }
      }

      raise err
    end
  end
end
