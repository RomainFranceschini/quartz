module Quartz
  # The `TimeCache` data structure is used to store and retrieve elapsed
  # durations since a particular event.
  class TimeCache
    # Returns the current time associated with the time cache.
    property current_time : TimePoint

    def initialize(@current_time : TimePoint = TimePoint.new(0))
    end

    # Retain the given *event* in order to track the elapsed duration since the
    # `#current_time` as time advances.
    def retain_event(event : Schedulable, precision : Scale)
      imaginary_duration = Duration.new(Duration::MULTIPLIER_MAX, precision)
      planned_phase = @current_time.phase_from_duration(imaginary_duration)
      event.imaginary_precision = precision
      event.imaginary_phase = planned_phase
    end

    # Retain the given *event* with a given *elapsed* duration since the
    # `#current_time`, in order to track it as time advances.
    def retain_event(event : Schedulable, elapsed : Duration)
      imaginary_duration = Duration.new(Duration::MULTIPLIER_MAX - elapsed.multiplier, elapsed.precision)
      planned_phase = @current_time.phase_from_duration(imaginary_duration)
      event.imaginary_precision = elapsed.precision
      event.imaginary_phase = planned_phase
    end

    # Returns the elapsed `Duration` associated with the given *event* since the
    # previous event.
    def elapsed_duration_of(event : Schedulable) : Duration
      id = @current_time.duration_from_phase(event.imaginary_phase)
      id = rescaled_duration(id, event.imaginary_precision)
      Duration.new(Duration::MULTIPLIER_MAX - id.multiplier, id.precision)
    end

    protected def rescaled_duration(duration : Duration, precision : Scale) : Duration
      if duration.precision > precision
        @current_time.refined_duration(duration, precision)
      else
        Duration.new(duration.multiplier, precision)
      end
    end

    # Cancel the tracking of the elapsed duration since the previous event of
    # the given *event*.
    def release_event(event : Schedulable)
      event.imaginary_phase = Duration::INFINITY
    end

    # Advance the current time by the given `Duration` relative to the current
    # time.
    def advance(by duration : Duration) : TimePoint
      @current_time.advance(duration)
    end

    # Advance the current time until match the given `TimePoint`.
    def advance(until time_point : TimePoint) : TimePoint
      while @current_time != time_point
        advance by: time_point.gap(@current_time)
      end
      @current_time
    end
  end
end
