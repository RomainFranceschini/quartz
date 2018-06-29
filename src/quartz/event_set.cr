module Quartz
  # The `Schedulable` module is used as an interface for data types that may
  # be scheduled within an `EventSet`.
  module Schedulable
    # The planned phase, or the offset from the current epoch of the
    # event set, associated with the event.
    property planned_phase : Duration = Duration::INFINITY.fixed
    # The original precision level at which the event was originally planned.
    property planned_precision : Scale = Scale::BASE
    # The imaginary planned phase used to track elapsed times.
    property imaginary_phase : Duration = Duration::INFINITY.fixed
    # The original precision level at which the imaginary event was originally
    # planned.
    property imaginary_precision : Scale = Scale::BASE
  end


  # A `PriorityQueue` is the base class to implement a planning strategy for all
  # future events to be evaluated. Events should be dequeued in a strict order
  # of precedence, according to their associated priority.
  #
  # The priority is represented by the `Duration` data type, which represent a
  # planned phase, an offset from the beginning of the current epoch relative
  # to the current simulated time.
  #
  # It is internally used by the pending event set `EventSet`.
  abstract class PriorityQueue(T)
    def self.new(priority_queue : Symbol, &comparator : Duration, Duration -> Int32) : self
      case priority_queue
      # when :ladder_queue   then LadderQueue(T).new(&comparator)
      # when :calendar_queue then CalendarQueue(T).new(&comparator)
      when :binary_heap then BinaryHeap(T).new(&comparator)
      else
        if (logger = Quartz.logger?) && logger.warn?
          logger.warn("Unknown priority queue '#{priority_queue}', defaults to binary heap")
        end
        # CalendarQueue(T).new(&comparator)
        BinaryHeap(T).new(&comparator)
      end
    end

    abstract def initialize(&comparator : Duration, Duration -> Int32)
    abstract def size : Int
    abstract def empty? : Bool
    abstract def clear
    abstract def push(priority : Duration, value : T)
    abstract def peek : T
    abstract def peek? : T?
    abstract def pop : T
    abstract def delete(priority : Duration, value : T)
    abstract def next_priority : Duration
  end

  # `EventSet` represents the pending event set and encompasses all future
  # events scheduled to occur.
  class EventSet(T)
    # Returns the current time associated with the event set.
    getter current_time : TimePoint

    getter priority_queue : PriorityQueue(T)

    def self.new(time : TimePoint = TimePoint.new(0)) : self
      new(:calendar_queue, time)
    end

    def initialize(priority_queue : Symbol, @current_time : TimePoint = TimePoint.new(0))
      {% if T < Schedulable || (T.union? && T.union_types.all? { |t| t < Schedulable }) %}
        # Only support Schedulable types
      {% else %}
        {{ raise "Can only create EventSet with types that implements Schedulable, not #{T}" }}
      {% end %}

      @priority_queue = PriorityQueue(T).new(priority_queue) { |a, b|
        cmp_planned_phases(a, b)
      }
      @future_events = Set(T).new
    end

    # Returns the number of scheduled events.
    def size
      @priority_queue.size + @future_events.size
    end

    # Whether the event set is empty.
    def empty? : Bool
      @priority_queue.empty? && @future_events.empty?
    end

    # Clears `self`.
    def clear
      @current_time = TimePoint.new
      @priority_queue.clear
      @future_events.clear
    end

    # Advance the current time up to the next planned event.
    def advance : TimePoint
      duration = imminent_duration
      if duration.infinite?
        @current_time
      else
        @current_time.advance(duration)
      end
    end

    # Advance the current time up to the specified planned duration using
    # a multiscale time advancement.
    #
    # Raises if the current time advances beyond the imminent events.
    def advance(by duration : Duration) : TimePoint
      if duration > imminent_duration
        raise BadSynchronisationError.new("Current time cannot advance beyond imminent events.")
      end
      @current_time.advance by: duration
    end

    # Advance the current time until it reaches the given time point.
    def advance(until t : TimePoint) : TimePoint
      while @current_time != t
        advance by: t.gap(@current_time)
      end
      @current_time
    end

    # Cancel the specified event.
    def cancel_event(event : T)
      if @future_events.includes?(event)
        @future_events.delete(event)
        event
      else
        @priority_queue.delete(event.planned_phase, event)
      end
    end

    # Returns the planned duration after which the specified event will occur.
    def duration_of(event : T) : Duration
      precision = event.planned_precision
      duration = @current_time.duration_from_phase(event.planned_phase)
      rescaled_duration(duration, precision)
    end

    # Schedules a future event at a given planned *duration*.
    def plan_event(event : T, duration : Duration)
      planned_phase = @current_time.phase_from_duration(duration)

      event.planned_precision = duration.precision
      event.planned_phase = planned_phase

      if planned_phase < duration || planned_phase > Duration.new(Duration::MULTIPLIER_MAX, duration.precision)
        # The event is in the next epoch
        @future_events.add(event)
      else
        @priority_queue.push(planned_phase, event)
      end

      planned_phase
    end

    # Returns the planned `Duration` associated with the future imminent events
    # to occur, or `Duration::INFINIY` if `self` is empty.
    def imminent_duration : Duration
      if @priority_queue.empty?
        if @future_events.empty?
          return Duration::INFINITY
        else
          plan_next_epoch_events
        end
      end

      duration_of(@priority_queue.peek)
    end

    # Deletes and returns the next imminent event to occur.
    def pop_imminent_event : T
      @priority_queue.pop
    end

    # Deletes and returns all imminent simultaneous events.
    def pop_imminent_events : Array(T)
      priority = @priority_queue.next_priority
      ary = [] of T
      while !@priority_queue.empty? && @priority_queue.next_priority == priority
        ary << @priority_queue.pop
      end
      ary
    end

    # Deletes and yields each imminent simultaneous event.
    def each_imminent_event
      priority = @priority_queue.next_priority
      while !@priority_queue.empty? && @priority_queue.next_priority == priority
        yield @priority_queue.pop
      end
    end

    def peek_imminent_events : Array(T)
      raise Exception.new("Not implemented.")
    end

    def reschedule!
      raise Exception.new("Not implemented.")
    end

    private def plan_next_epoch_events
      @future_events.each do |event|
        @priority_queue.push(event.planned_phase, event)
      end
      @future_events.clear
    end

    protected def rescaled_duration(duration : Duration, precision : Scale) : Duration
      if duration.precision > precision
        @current_time.refined_duration(duration, precision)
      else
        Duration.new(duration.multiplier, precision)
      end
    end

    # Compares two planned phases that may have different precision levels.
    protected def cmp_planned_phases(a : Duration, b : Duration) : Int32
      duration_a = @current_time.duration_from_phase(a)
      duration_b = @current_time.duration_from_phase(b)

      if duration_a.precision < duration_b.precision
        duration_b = @current_time.refined_duration(duration_b, duration_a.precision)
      elsif duration_a.precision > duration_b.precision
        duration_a = @current_time.refined_duration(duration_a, duration_b.precision)
      end

      duration_a <=> duration_b
    end
  end
end
