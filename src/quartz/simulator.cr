module Quartz
  class Simulator < Processor

    @int_count : UInt32 = 0u32
    @ext_count : UInt32 = 0u32
    @con_count : UInt32 = 0u32

    def transition_stats
      {
        internal: @int_count,
        external: @ext_count,
        confluent: @con_count
      }
    end

    def initialize_processor(time)
      atomic = @model.as(AtomicModel)
      @int_count = @ext_count = @con_count = 0u32

      @time_last = atomic.time = time
      @time_next = @time_last + atomic.time_advance
      atomic.notify_observers({ :transition => Any.new(:init) })
      if (logger = Quartz.logger?) && logger.debug?
        logger.debug "\t#{model} initialization (time_last: #{@time_last}, time_next: #{@time_next})"
      end
      @time_next
    end

    def collect_outputs(time) : Hash(Port,Any)
      raise BadSynchronisationError.new("time: #{time} should match time_next: #{@time_next}") if time != @time_next
      @model.as(AtomicModel).fetch_output!
    end

    def perform_transitions(time, bag)
      synced = @time_last <= time && time <= @time_next
      atomic = @model.as(AtomicModel)

      kind = nil
      if time == @time_next
        atomic.elapsed = 0
        if bag.empty?
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug "\tinternal transition: #{@model}"
          end
          @int_count += 1u32
          atomic.internal_transition
          kind = :internal
        else
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug "\tconfluent transition: #{@model}"
          end
          @con_count += 1u32
          atomic.confluent_transition(bag)
          kind = :confluent
        end
      elsif synced && !bag.empty?
        if (logger = Quartz.logger?) && logger.debug?
          logger.debug "\texternal transition: #{@model}"
        end
        @ext_count += 1u32
        atomic.elapsed = time - @time_last
        atomic.external_transition(bag)
        kind = :external
      elsif !synced
        raise BadSynchronisationError.new("time: #{time} should be between time_last: #{@time_last} and time_next: #{@time_next}")
      end

      @time_last = atomic.time = time
      @time_next = @time_last + atomic.time_advance
      atomic.notify_observers({ :transition => Any.new(kind) })

      if (logger = Quartz.logger?) && logger.debug?
        logger.debug("\t\ttime_last: #{@time_last} | time_next: #{@time_next}")
      end
      @time_next
    end
  end
end
