module Quartz
  class Simulator < Processor

    # :nodoc:
    OBS_INFO_INIT_TRANSITION = { :transition => Any.new(:init) }
    # :nodoc:
    OBS_INFO_INT_TRANSITION = { :transition => Any.new(:internal) }
    # :nodoc:
    OBS_INFO_EXT_TRANSITION = { :transition => Any.new(:external) }
    # :nodoc:
    OBS_INFO_CON_TRANSITION = { :transition => Any.new(:confluent) }

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

    def initialize_processor(time)
      atomic = @model.as(AtomicModel)
      @int_count = @ext_count = @con_count = 0u32

      @time_last = atomic.time = time
      atomic.__initialize_state__(self)
      @time_next = @time_last + atomic.time_advance

      if @run_validations && atomic.invalid?(:initialization)
        if (logger = Quartz.logger?) && logger.error?
          logger.error(String.build { |str|
            str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
            str << " (context: 'init', time: " << time << "). "
            str << "Errors: " << atomic.errors.full_messages
          })
        end
      end

      if (logger = Quartz.logger?) && logger.debug?
        logger.debug(String.build { |str|
          str << '\'' << atomic.name << "' initialized ("
          str << "tl: " << @time_last << ", tn: " << @time_next << ')'
        })
      end

      atomic.notify_observers(OBS_INFO_INIT_TRANSITION)

      @time_next
    rescue err : StrictValidationFailed
      atomic = @model.as(AtomicModel)
      if (logger = Quartz.logger?) && logger.fatal?
        logger.fatal(String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: 'init', time: " << time << "). "
          str << "Errors: " << atomic.errors.full_messages
        })
      end
      raise err
    end

    def collect_outputs(time)
      raise BadSynchronisationError.new("time: #{time} should match time_next: #{@time_next}") if time != @time_next
      @model.as(AtomicModel).fetch_output!
    end

    def perform_transitions(time, bag)
      synced = @time_last <= time && time <= @time_next
      atomic = @model.as(AtomicModel)

      info = nil
      kind = nil
      if time == @time_next
        atomic.elapsed = 0
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
      elsif synced && !bag.empty?
        @ext_count += 1u32
        atomic.elapsed = time - @time_last
        atomic.external_transition(bag)
        info = OBS_INFO_EXT_TRANSITION
        kind = :external
      elsif !synced
        raise BadSynchronisationError.new("time: #{time} should be between time_last: #{@time_last} and time_next: #{@time_next}")
      end

      @time_last = atomic.time = time
      @time_next = @time_last + atomic.time_advance

      if (logger = Quartz.logger?) && logger.debug?
        logger.debug(String.build { |str|
          str << '\'' << atomic.name << "': " << kind << " transition "
          str << "(tl: " << @time_last << ", tn: " << @time_next << ')'
        })
      end

      if @run_validations && atomic.invalid?(kind)
        if (logger = Quartz.logger?) && logger.error?
          logger.error(String.build { |str|
            str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
            str << " (context: '" << kind << "', time: )" << time << "). "
            str << "Errors: " << atomic.errors.full_messages
          })
        end
      end

      atomic.notify_observers(info)

      @time_next
    rescue err : StrictValidationFailed
      atomic = @model.as(AtomicModel)
      if (logger = Quartz.logger?) && logger.fatal?
        logger.fatal(String.build { |str|
          str << '\'' << atomic.name << "' is " << "invalid".colorize.underline
          str << " (context: 'init', time: " << time << "). "
          str << "Errors: " << atomic.errors.full_messages
        })
      end
      raise err
    end
  end
end
