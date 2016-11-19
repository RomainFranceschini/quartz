module Quartz
  class Simulator < Processor

    def initialize(model : Model)
      super(model)
      @transition_count = Hash(Symbol, UInt64).new { 0_u64 }
    end

    def transition_stats
      @transition_count
    end

    def initialize_processor(time)
      atomic = @model.as(AtomicModel)
      @transition_count.clear
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
          @transition_count[:internal] += 1
          atomic.internal_transition
          kind = :internal
        else
          if (logger = Quartz.logger?) && logger.debug?
            logger.debug "\tconfluent transition: #{@model}"
          end
          @transition_count[:confluent] += 1
          atomic.confluent_transition(bag)
          kind = :confluent
        end
      elsif synced && !bag.empty?
        if (logger = Quartz.logger?) && logger.debug?
          logger.debug "\texternal transition: #{@model}"
        end
        @transition_count[:external] += 1
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
