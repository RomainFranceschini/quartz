module Quartz::DTSS
  # This class defines a DTSS simulator.
  class Simulator < Quartz::Processor
    @transition_count : UInt32 = 0u32
    @run_validations : Bool

    def initialize(model : Model, simulation : Simulation)
      @run_validations = simulation.run_validations?
      super(model)
    end

    def transition_stats
      {
        transition: @transition_count,
      }
    end

    def initialize_processor(time : TimePoint) : {Duration, Duration}
      atomic = @model.as(DTSS::AtomicModel)
      @transition_count = 0u32

      atomic.__initialize_state__(self)

      planned_duration = atomic.class.time_delta

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
          str << "time_next: " << planned_duration << ')'
        }
      }

      if atomic.count_observers > 0
        atomic.notify_observers(OBS_INFO_INIT_TRANSITION.merge({:time => time}))
      end

      elapsed = Duration.zero(atomic.model_precision, true)
      {elapsed, planned_duration.fixed}
    rescue err : StrictVerificationFailed
      atomic = @model.as(DTSS::AtomicModel)

      Log.fatal {
        String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: 'init', time: " << time << "). "
          str << "Errors: " << atomic.errors.full_messages
        }
      }

      raise err
    end

    def collect_outputs(_elapsed : Duration) : Hash(Quartz::OutputPort, Array(Quartz::Any))
      @model.as(DTSS::AtomicModel).fetch_output!
    end

    def perform_transitions(time : TimePoint, elapsed : Duration, imminent : Bool = false) : Duration
      atomic = @model.as(DTSS::AtomicModel)
      bag = @bag || EMPTY_BAG

      kind = nil
      planned_duration = atomic.class.time_delta

      if elapsed != planned_duration
        raise BadSynchronisationError.new("#{model.name} is unsynced (elapsed:#{elapsed}, bag size:#{bag.size}, time:#{time}).")
      else
        @transition_count += 1u32
        atomic.transition(bag)
      end

      bag.clear

      Log.debug {
        String.build { |str|
          str << '\'' << atomic.name << "': " << kind << " transition "
          str << "time_next: " << planned_duration << ')'
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
        atomic.notify_observers({:time => time, :elapsed => elapsed})
      end

      planned_duration.fixed
    rescue err : StrictVerificationFailed
      atomic = @model.as(DTSS::AtomicModel)

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
