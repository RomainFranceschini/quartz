module Quartz
  module PDEVS
    class Simulator < Quartz::Simulator
      def initialize_processor(time)
        atomic = @model as AtomicModel
        @transition_count.clear
        @time_last = atomic.time = time
        @time_next = @time_last + atomic.time_advance
        atomic.notify_observers(atomic, :init)
        #debug "\t#{model} initialization (time_last: #{@time_last}, time_next: #{@time_next})" if Quartz.logger && Quartz.logger.debug?
        @time_next
      end

      def collect_outputs(time) : Hash(Port,Any)
        raise BadSynchronisationError.new("time: #{time} should match time_next: #{@time_next}") if time != @time_next
        (@model as AtomicModel).fetch_output!
      end

      def perform_transitions(time, bag)
        synced = @time_last <= time && time <= @time_next
        atomic = @model as AtomicModel

        kind = nil
        if time == @time_next
          atomic.elapsed = 0
          if bag.empty?
            #debug "\tinternal transition: #{@model}" if Quartz.logger && Quartz.logger.debug?
            @transition_count[:internal] += 1
            atomic.internal_transition
            kind = :internal
          else
            #debug "\tconfluent transition: #{@model}" if Quartz.logger && Quartz.logger.debug?
            @transition_count[:confluent] += 1
            atomic.confluent_transition(bag)
            kind = :confluent
          end
        elsif synced && !bag.empty?
          #debug "\texternal transition: #{@model}" if Quartz.logger && Quartz.logger.debug?
          @transition_count[:external] += 1
          atomic.elapsed = time - @time_last
          atomic.external_transition(bag)
          kind = :external
        elsif !synced
          raise BadSynchronisationError.new("time: #{time} should be between time_last: #{@time_last} and time_next: #{@time_next}")
        end

        @time_last = atomic.time = time
        @time_next = @time_last + atomic.time_advance
        atomic.notify_observers(atomic, kind)

        #debug "\t\ttime_last: #{@time_last} | time_next: #{@time_next}" if Quartz.logger && Quartz.logger.debug?
        @time_next
      end
    end
  end
end
