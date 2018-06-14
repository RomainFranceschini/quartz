module Quartz
  # The `TimeCache` data structure is used to store and retrieve elapsed
  # durations since a particular event.
  class TimeCache(T)
    # A `PhaseDelegate` to use with `TimeCache`, which re-purpose the `EventSet`.
    # Store phases with `Schedulable#imaginary_phase` property.
    private module TimeCachePhaseDelegate
      extend PhaseDelegate

      def self.get_phase(of event : Schedulable) : Duration
        event.imaginary_phase
      end

      def self.set_phase(phase : Duration, for event : Schedulable)
        event.imaginary_phase = phase
      end

      def self.get_precision(of event : Schedulable) : Scale
        event.imaginary_precision
      end

      def self.set_precision(precision : Scale, for event : Schedulable)
        event.imaginary_precision = precision
      end
    end

    def self.new(time : TimePoint = TimePoint.new(0)) : self
      new(:calendar_queue, time)
    end

    def initialize(priority_queue : Symbol, time : TimePoint = TimePoint.new(0))
      @time_queue = EventSet(T).new(priority_queue, time, TimeCachePhaseDelegate)
    end

    # Returns the current time associated with the encapsulated event set.
    delegate current_time, to: @time_queue

    # Returns the number of retained events in `self`.
    delegate size, to: @time_queue

    # Retain the given *event* in order to track the elapsed duration since the
    # `#current_time` as time advances.
    def retain_event(event : T, precision : Scale)
      imaginary_event = Duration.new(Duration::MULTIPLIER_MAX, precision)
      @time_queue.plan_event(event, imaginary_event)
    end

    # Retain the given *event* with a given *elapsed* duration since the
    # `#current_time`, in order to track it as time advances.
    def retain_event(event : T, elapsed : Duration)
      imaginary_event = Duration.new(Duration::MULTIPLIER_MAX - elapsed.multiplier, elapsed.precision)
      @time_queue.plan_event(event, imaginary_event)
    end

    # Returns the elapsed `Duration` associated with the given *event* since the
    # previous event.
    def elapsed_duration_of(event : T) : Duration
      imaginary_duration = @time_queue.duration_of(event)
      multiplier = Duration::MULTIPLIER_MAX - imaginary_duration.multiplier
      Duration.new(multiplier, imaginary_duration.precision)
    end

    # Cancel the tracking of the elapsed duration since the previous event of
    # the given *event*.
    def release_event(event : T)
      @time_queue.cancel_event(event)
    end

    # Advance the current time by the given `Duration` relative to the current
    # time, and remove obsolete imaginary events.
    def advance(by duration : Duration) : TimePoint
      imminent_duration = @time_queue.imminent_duration
      while duration >= imminent_duration
        # Remove obsolete imaginary events
        @time_queue.each_imminent_event {
          # no-op
        }
        imminent_duration = @time_queue.imminent_duration
      end

      @time_queue.advance(duration)
    end

    # Advance the current time until the given `TimePoint` and remove obsolete
    # imaginary events.
    def advance(until time_point : TimePoint) : TimePoint
      while current_time != time_point
        advance by: time_point.gap(current_time)
      end
      current_time
    end
  end
end
