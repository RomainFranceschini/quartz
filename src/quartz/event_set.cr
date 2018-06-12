module Quartz
  # The `Schedulable` module is used as an interface for data types that may
  # be scheduled within an `EventSet`.
  module Schedulable
    # Represents the planned phase, or the offset from the current epoch of the
    # event set, associated with the event.
    property planned_phase : Duration = Duration::INFINITY.fixed
    # Represents the imaginary planned phase.
    property imaginary_phase : Duration = Duration::INFINITY.fixed
  end

  # The `PhaseDelegate` mixin is used as an interface to represent an `EventSet`
  # delegate object, which must adopt the `#get_phase` and `#set_phase` methods.
  #
  # The delegate manage the storage and the retrieval of a phase (offset from
  # event set current epoch) associated with a given event.
  module PhaseDelegate
    abstract def get_phase(of event : Schedulable) : Duration
    abstract def set_phase(phase : Duration, for event : Schedulable)
  end

  # A `PhaseDelegate` to use as a default with an `EventSet`.
  # Store phases with `Schedulable#planned_phase` property.
  module EventSetPhaseDelegate
    extend PhaseDelegate

    def self.get_phase(of event : Schedulable) : Duration
      event.planned_phase
    end

    def self.set_phase(phase : Duration, for event : Schedulable)
      event.planned_phase = phase
    end
  end

  # A `PhaseDelegate` to use with `TimeCache`, which re-purpose the `EventSet`.
  # Store phases with `Schedulable#imaginary_phase` property.
  module TimeCachePhaseDelegate
    extend PhaseDelegate

    def self.get_phase(of event : Schedulable) : Duration
      event.imaginary_phase
    end

    def self.set_phase(phase : Duration, for event : Schedulable)
      event.imaginary_phase = phase
    end
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

    def self.new(time : TimePoint = TimePoint.new(0), delegate : PhaseDelegate = EventSetPhaseDelegate) : self
      new(:calendar_queue, time)
    end

    def initialize(priority_queue : Symbol, @current_time : TimePoint = TimePoint.new(0), delegate : PhaseDelegate = EventSetPhaseDelegate)
      {% if T < Schedulable || (T.union? && T.union_types.all? { |t| t < Schedulable }) %}
        # Only support Schedulable types
      {% else %}
        {{ raise "Can only create EventSet with types that implements Schedulable, not #{T}" }}
      {% end %}

      @delegate = delegate
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
      @priority_queue.clear
      @future_events.clear
    end

    # Advance the current time up to the next planned event.
    def advance : TimePoint
      duration = imminent_duration
      if duration.infinite?
        @current_time
      else
        @current_time = @current_time.advance(duration)
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
      @current_time = @current_time.advance by: duration
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
      phase = @delegate.get_phase(event)
      if @future_events.includes?(event)
        @future_events.delete(event)
        event
      else
        @priority_queue.delete(phase, event)
      end
    end

    # Returns the planned duration after which the specified event will occur.
    def duration_of(event : T) : Duration
      duration_from_phase(@delegate.get_phase(event))
    end

    # Schedules a future event at a given planned *duration*.
    def plan_event(event : T, duration : Duration)
      planned_phase = phase_from_duration(duration)

      @delegate.set_phase(planned_phase, event)
      if planned_phase < duration
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

      duration_from_phase(@priority_queue.next_priority)
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
        @priority_queue.push(@delegate.get_phase(event), event)
      end
      @future_events.clear
    end

    # Converts a planned duration to a planned phase (offset from epoch).
    protected def phase_from_duration(duration : Duration) : Duration
      t = @current_time
      if duration.zero?
        duration = duration.rescale(t.precision)
      end

      precision = duration.precision
      multiplier = duration.multiplier + epoch_phase(precision)
      maximized = false
      unbounded = false

      while !maximized && !unbounded
        carry = 0
        if multiplier > Duration::MULTIPLIER_MAX
          multiplier -= Duration::MULTIPLIER_LIMIT
          carry = 1
        end

        if multiplier % Scale::FACTOR != 0
          maximized = true
        elsif multiplier == 0 && precision + Duration::EPOCH >= t.precision + t.size
          unbounded = true if carry == 0
        end

        if !maximized && !unbounded
          multiplier /= Scale::FACTOR
          multiplier += Scale::FACTOR ** (Duration::EPOCH - 1) * (t[precision + Duration::EPOCH]) # + carry)
          precision += 1
        end
      end

      precision = Scale::BASE if unbounded

      Duration.new(multiplier, precision)
    end

    # Converts a planned phase (offset from epoch) to a planned duration
    # (relative to the current time).
    protected def duration_from_phase(phase : Duration) : Duration
      precision = phase.precision
      multiplier = phase.multiplier - epoch_phase(precision)

      if multiplier < 0
        multiplier += Duration::MULTIPLIER_LIMIT
      end

      Duration.new(multiplier, precision)
    end

    # Returns the epoch phase, which represents the number of time quanta which
    # separates `self` from the beginning of the current epoch.
    protected def epoch_phase(precision : Scale) : Int64
      t = @current_time
      multiplier = 0_i64
      (0...Duration::EPOCH).each do |i|
        multiplier += Scale::FACTOR ** i * t[precision + i]
      end
      multiplier
    end

    # Refines a planned `Duration` to match another planned duration precision.
    #
    # Note: The implementation diverge from the paper algoithm.
    protected def refined_duration(duration : Duration, refined : Scale) : Duration
      t = @current_time
      precision = duration.precision
      multiplier = duration.multiplier

      if multiplier > 0
        while multiplier < Duration::MULTIPLIER_LIMIT && precision > refined
          precision -= 1
          multiplier = Scale::FACTOR * multiplier - t[precision]
        end
      end

      if multiplier < Duration::MULTIPLIER_LIMIT
        Duration.new(multiplier, refined)
      else
        Duration::INFINITY
      end
    end

    protected def rescaled_duration(duration : Duration, precision : Scale) : Duration
      if duration.precision <= precision
        refined_duration(duration, precision)
      else
        Duration.new(m, precision)
      end
    end

    # Compares two planned phases that may have different precision levels.
    protected def cmp_planned_phases(a : Duration, b : Duration) : Int32
      duration_a = duration_from_phase(a)
      duration_b = duration_from_phase(b)

      if duration_a.precision < duration_b.precision
        duration_b = refined_duration(duration_b, duration_a.precision)
      elsif duration_a.precision > duration_b.precision
        duration_a = refined_duration(duration_a, duration_b.precision)
      end

      duration_a <=> duration_b
    end
  end
end
