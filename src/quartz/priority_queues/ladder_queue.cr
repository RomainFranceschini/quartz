module Quartz
  # :nodoc:
  # Multilist-based priority queue structure which achieve O(1) performance,
  # especially designed for managing the pending event set in discrete event
  # simulation. Its name, *LadderQueue*, arises from the semblance of the
  # structure to a ladder with rungs.
  #
  # Basically, the structure consists of three tiers: a sorted list called
  # *Bottom*; the middle layer, called *Ladder*, consisting of several
  # rungs of buckets where each bucket may contain an unsorted list; and a
  # simple unsorted list called *Top*.
  #
  # See paper: Tang, Wai Teng, Rick Siow Mong Goh, and Ian Li-Jin Thng. 2005.
  # “Ladder Queue: an O(1) Priority Queue Structure for Large-Scale Discrete
  # Event Simulation.” ACM Transactions on Modeling and Computer Simulation
  # 15 (3): 175–204. doi:10.1145/1103323.1103324.
  class LadderQueue(T) < PriorityQueue(T)
    # This class represent a general error for the `LadderQueue`.
    class LadderQueueError < Exception; end

    # This class represent an error raised if the number of rungs in
    # *Ladder* is equal to `MAX_RUNGS` when an attempt to add a new rung
    # is made.
    class RungOverflowError < LadderQueueError; end

    # This class represent an error raised when an attempt to reset an active
    # `Rung` is made.
    class RungInUseError < LadderQueueError; end

    # The maximum number of events in a bucket or bottom to not exceed. If so,
    # a spawning action would be initiated.
    # See paper sec 2.3 and 2.4.
    THRESHOLD = 50

    # The maximum number of rungs in the middle layer (i.e. the ladder),
    # to prevent infinite rung spawning.
    # See paper sec 2.4.
    MAX_RUNGS = 8

    # Maximum timestamp of all events in top. Its value is updated as events
    # are enqueued into top
    @top_max : Duration

    # Minimum timestamp of all events in top. Its value is updated as events
    # are enqueued into top
    @top_min : Duration

    # Minimum timestamp threshold of events which must be enqueued in top
    @top_start : Duration

    # The number of spawned rungs
    @active_rungs : Int32

    # Returns the number of elements in the queue.
    getter size : Int32 = 0

    # Returns the number of garbage events remaining in the queue. Those could
    # not be deleted in a reasonable time.
    getter garbage : Int32 = 0

    getter epoch : Int32 = 0

    def initialize(&comparator : Duration, Duration, Bool -> Int32)
      @comparator = comparator

      # A simple unsorted list which represents the *Top* tier.
      @top = Array({Duration, T}).new

      # The middle layer (ladder) consisting of several rungs of buckets where
      # each bucket may contain an unsorted list
      @rungs = StaticArray(Rung(T), MAX_RUNGS).new { |i| Rung(T).new(i) }

      # Sorted list
      @bottom = Array({Duration, T}).new

      @top_max = Quartz.duration(0)
      @top_min = Duration::INFINITY
      @top_start = Quartz.duration(0)
      @active_rungs = 0

      Log.warn { "The LadderQueue has known issues with multiscale time that will break" \
                 "causality and/or cause errors." }
    end

    # Returns the number of elements contained in the *top* tier of the queue
    def top_size
      @top.size
    end

    # Returns the number of elements contained in the *bottom* tier of the queue
    def bottom_size
      @bottom.size
    end

    # Returns the number of elements contained in the *ladder* tier of the queue
    def ladder_size
      @size - (@top.size + @bottom.size)
    end

    # Whether this queue is empty
    def empty? : Bool
      @size == 0
    end

    def push(ts : Duration, value : T)
      @size += 1

      # check wether event should be in top
      if @comparator.call(ts, @top_start, false) >= 0
        @top << {ts, value}
        @top_min = ts if @comparator.call(ts, @top_min, false) < 0
        @top_max = ts if @comparator.call(ts, @top_max, false) > 0
        return self
      end

      # if priority is lower than the maximum priority from bottom, this
      # event should be in bottom.
      should_be_in_bottom = @bottom.size > 0 && @comparator.call(ts, @bottom.first[0], false) < 0

      # determine whether event should be in ladder or bottom
      rung_index = 0
      while rung_index < @active_rungs && @comparator.call(ts, @rungs[rung_index].current_priority, false) < 0
        rung_index += 1
      end

      if rung_index < @active_rungs && !should_be_in_bottom
        rung = @rungs[rung_index]

        unless @comparator.call(ts, rung.start_priority, false) >= 0
          raise LadderQueueError.new("#{ts} should be >= #{rung.start_priority}")
        end

        # insert event to appropriate rung
        rung.push(ts, value)

        return self
      end

      # check whether bottom exceed threshold
      if @bottom.size >= THRESHOLD
        # let bottom overflow threshold when MAX_RUNGS is reached.
        if @active_rungs == MAX_RUNGS
          push_bottom({ts, value})
          return self
        end

        max = @bottom.first[0]
        min = @bottom.last[0]
        diff = max - min

        # spawn bottom rung and transfer bottom into it only if timestamps
        # are not identical.
        if diff > Duration.zero(diff.precision)
          rung = spawn_rung_for_bottom(Math.min(ts, min))
          rung.concat(@bottom)
          rung.push(ts, value)
          @bottom.clear
        else
          push_bottom({ts, value})
        end
      else # bottom size is < to THRESHOLD
        push_bottom({ts, value})
      end

      self
    end

    private def push_bottom(tuple : {Duration, T})
      if @bottom.empty?
        @bottom << tuple
      else
        index = @bottom.size - 1
        while @comparator.call(tuple[0], @bottom[index][0], false) > 0 && index >= 0
          index -= 1
        end
        @bottom.insert(index + 1, tuple)
      end
    end

    # Returns the element having the highest priority.
    #
    # Raises if *self* is empty.
    def peek : T
      if @size > 0 && (tuple = unsafe_peek)
        tuple[1]
      else
        raise "ladder queue is empty."
      end
    end

    # Returns the element having the highest priority, or *nil* if *self* is
    # empty.
    def peek? : T?
      if @size > 0 && (tuple = unsafe_peek)
        tuple[1]
      else
        nil
      end
    end

    def next_priority : Duration
      if @size == 0
        raise "ladder queue is empty."
      else
        if tuple = unsafe_peek
          tuple[0]
        else
          Duration::INFINITY
        end
      end
    end

    private def unsafe_peek : Tuple(Duration, T)?
      loop do
        prepare! if @bottom.empty?

        if tuple = @bottom.last?
          if @comparator.call(tuple[0], tuple[1].planned_phase, false) == 0
            return tuple
          else # garbage event
            @garbage -= 1
            @bottom.pop
          end
        else
          break
        end
      end
      nil
    end

    # Remove from *self* and returns the element having the highest priority.
    def pop : T
      loop do
        raise "ladder queue is empty." if @size == 0

        prepare! if @bottom.empty?

        tuple = @bottom.pop
        if @comparator.call(tuple[0], tuple[1].planned_phase, false) == 0
          @size -= 1
          return tuple[1]
        else
          @garbage -= 1
        end
      end
    end

    def delete(priority : Duration, event : T) : T?
      item = nil

      prepare! if @bottom.empty?

      if @comparator.call(priority, @top_start, false) < 0
        x = 0
        while x < @active_rungs && @comparator.call(priority, @rungs[x].current_priority, false) < 0
          x += 1
        end

        item = @rungs[x].delete(priority, event) if x < @active_rungs
      end

      @size -= 1

      unless item
        @garbage += 1
      end
      item
    end

    # Clears *self*.
    def clear
      @top.clear
      @bottom.clear
      @rungs.each &.clear

      @active_rungs = 0
      @size = 0
      @garbage = 0
    end

    private def prepare!
      while @bottom.empty?
        if @active_rungs > 0
          rung = recurse_rungs

          unless rung.empty?
            # transfer next non-empty bucket from lowest rung to bottom
            rung.current_bucket.each do |ev|
              push_bottom(ev)
            end

            rung.clear_current_bucket
          end

          # invalidate empty rungs
          while @active_rungs > 0 && rung.empty?
            rung.clear
            @active_rungs -= 1
            rung = @rungs[@active_rungs - 1]
          end
        else                      # no more events in ladder or bottom, new epoch
          break if @top.size == 0 # no more events in top, nothing to do

          # all timestamps are identical, no sort required
          # transfer directly events from top into bottom
          if @top_max - @top_min == Duration.zero
            tmp = @bottom
            @bottom = @top
            @top = tmp
          else
            rung = spawn_rung(@top.size)
            rung.concat(@top)
            @top.clear
          end

          @epoch += 1
          @top_start = @top_max
          @top_max = @top_start
          @top_min = @top_start
        end
      end
    end

    private def recurse_rungs : Rung
      lowest = @rungs[@active_rungs - 1]

      return lowest if lowest.empty?

      # until an acceptable bucket is found
      loop do
        # find next non-empty bucket
        lowest.forward

        # create a new rung if bucket gets too big
        if lowest.current_bucket_count > THRESHOLD
          if @active_rungs == MAX_RUNGS
            # if self reached its maximum number of rungs, events in the
            # current dequeue bucket, associated with the last rung, are
            # sorted to create *bottom* even though the number of events may
            # exceed threshold.
            break
          else
            # spawn a new rung
            rung = spawn_rung(lowest.current_bucket_count)
            rung.concat(lowest.current_bucket)
            lowest.clear_current_bucket
            lowest = rung
          end
        else
          break # found
        end
      end

      lowest
    end

    private def spawn_rung(n_events) : Rung
      raise RungOverflowError.new if @active_rungs == MAX_RUNGS

      if @active_rungs == 0
        rung = @rungs.first
        width = (@top_max - @top_min) / n_events
        rung.set(width, n_events, @top_min)
        @active_rungs = 1
        rung
      else # static rungs
        current_rung = @rungs[@active_rungs - 1]
        rung = @rungs[@active_rungs]
        # set bucket width to current rung's bucket width / thres
        width = current_rung.bucket_width / THRESHOLD
        # set start and current of the new rung to current marking of the
        # current rung
        rung.set(width, Rung::MAX_RUNG_SIZE, current_rung.current_priority)
        @active_rungs += 1
        rung
      end
    end

    private def spawn_rung_for_bottom(start) : Rung
      max = @bottom.first[0]
      if @active_rungs == 0
        raise LadderQueueError.new unless @comparator.call(start, @top_start, false) < 0
        rung = @rungs.first
        width = (max - start) / @bottom.size
        rung.set(width, @bottom.size, start)
        @active_rungs = 1
        rung
      else
        current_rung = @rungs[@active_rungs - 1]
        rung = @rungs[@active_rungs]
        raise LadderQueueError.new unless @comparator.call(start, current_rung.current_priority, false) < 0
        width = (max - start) / THRESHOLD
        rung.set(width, Rung::MAX_RUNG_SIZE, start)
        @active_rungs += 1
        rung
      end
    end

    # This class represent a rung used in the *ladder* tier of a
    # `LadderQueue`.
    #
    # Consist of buckets where each bucket may contain an unsorted list.
    private class Rung(T)
      include Indexable(Array({Duration, T}))

      # The maximum number of buckets in a rung *i*, where *i > 1* is equal to
      # the `LadderQueue::THRESHOLD` value.
      # See paper sec 2.4.
      MAX_RUNG_SIZE = 50

      # Returns the number of buckets in this rung
      getter size : Int32 = 0

      # Buckets capacity
      @capa : Int32 = 0
      @buckets : Pointer(Array({Duration, T}))
      @start : Duration = Duration.new(0)
      @width : Duration = Duration.new(0)
      @index : Int32 = 0
      @id : Int32 = 0

      # Returns the number of elements in this rung
      getter count : Int32 = 0

      def initialize(@id)
        if @id == 0 || @id > 5
          @capa = 0
          @buckets = Pointer(Array({Duration, T})).null
        else
          @capa = MAX_RUNG_SIZE
          @buckets = Pointer(Array({Duration, T})).malloc(@capa) {
            Array({Duration, T}).new
          }
        end
      end

      @[AlwaysInline]
      def empty? : Bool
        @count == 0
      end

      # Returns the bucket width.
      @[AlwaysInline]
      def bucket_width : Duration
        @width
      end

      # Returns the start priority.
      @[AlwaysInline]
      def start_priority : Duration
        @start
      end

      # Returns the number of elements in the current bucket.
      @[AlwaysInline]
      def current_bucket_count
        @buckets[@index].size
      end

      # Returns the beginning of the priority interval managed by the current
      # bucket.
      @[AlwaysInline]
      def current_priority : Duration
        res = @start + @index*@width
        res
      end

      # Returns the priority interval managed by the current bucket.
      @[AlwaysInline]
      def current_interval : Range(Duration, Duration)
        (current_priority...(current_priority + @width))
      end

      # Returns the priority interval managed by *self*.
      @[AlwaysInline]
      def interval : Range(Duration, Duration)
        (@start...max_priority)
      end

      # Returns the maximum priority that *self* might contain.
      @[AlwaysInline]
      def max_priority : Duration
        @start + @size*@width
      end

      # Find next non-empty bucket in *self*.
      @[AlwaysInline]
      def forward
        (@index...@size).each do |i|
          if @buckets[i].size > 0
            @index = i
            break
          end
        end
      end

      # Rewind *self* to the first bucket.
      @[AlwaysInline]
      def rewind
        @index = 0
      end

      # Clears *self*.
      #
      # Raises a `RungInUseError` if *self* contains any element.
      def clear
        raise RungInUseError.new if @count > 0
        @start = Duration.new(0)
        @index = 0
        @width = Duration.new(0)
        @size = 0
        @count = 0
      end

      # Reset *self* so that it can be (re-)used.
      #
      # Raises a `RungInUseError` if *self* contains any element.
      def set(width : Duration, buckets : Int, start : Duration)
        raise RungInUseError.new if @count > 0

        if @id == 0
          if @buckets.null?
            # double the number of required buckets. see paper sec 2.4.
            @capa = buckets * 2
            @buckets = Pointer(Array({Duration, T})).malloc(@capa) {
              Array({Duration, T}).new
            }
          else
            # double the number of required buckets if needed.
            # see paper sec 2.4.
            if buckets >= @capa
              new_capa = buckets * 2
              @buckets = @buckets.realloc(new_capa)
              (@capa...new_capa).each { |i|
                @buckets[i] = Array({Duration, T}).new
              }
              @capa = new_capa
            end
          end
        else # static rung
          if @buckets.null?
            @capa = MAX_RUNG_SIZE
            @buckets = Pointer(Array({Duration, T})).malloc(@capa) {
              Array({Duration, T}).new
            }
          end

          if buckets > @capa
            raise RungOverflowError.new("rung size (#{buckets}) should be < to #{@capa}")
          end
        end

        @size = buckets
        @width = width
        @start = start
        @count = 0
        @index = 0
      end

      @[AlwaysInline]
      def push(prio : Duration, obj : T)
        @buckets[index_for(prio)] << {prio, obj}
        @count += 1
      end

      @[AlwaysInline]
      def concat(events)
        events.each { |tuple|
          @buckets[index_for(tuple[0])] << tuple
        }
        @count += events.size
      end

      @[AlwaysInline]
      def pos=(index)
        @index = index if index < @size
      end

      # Returns the current bucket index.
      @[AlwaysInline]
      def pos
        @index
      end

      def delete(priority : Duration, obj : T) : T?
        item = nil
        bucket = @buckets[index_for(priority)]
        i = bucket.index(obj)
        if i
          item = bucket.delete_at(i)[1]
          @count -= 1
        end
        item
      end

      # Clears the current bucket in *self*.
      def clear_current_bucket
        bucket = @buckets[@index]
        @count -= bucket.size
        bucket.clear
      end

      # Returns the current bucket
      @[AlwaysInline]
      def current_bucket : Array({Duration, T})
        @buckets[@index]
      end

      @[AlwaysInline]
      def unsafe_fetch(index : Int) : Array({Duration, T})
        @buckets[index]
      end

      # Returns the index maching the given priority
      @[AlwaysInline]
      def index_for(priority : Duration) : Int
        Math.min(
          ((priority - @start) / @width).to_f.to_i64,
          @size - 1
        )
      end

      def inspect(io : IO)
        io.print("[#{start_priority},#{start_priority + ((size - 1) * bucket_width)}[ • ")
        io.puts("Rung##{@id}: cur=#{current_priority} (#{count} elements)")
        (0...size).each do |j|
          next if @buckets[j].empty? && j != pos

          io.print("    ")
          io.print("[#{start_priority + (j * bucket_width)},#{start_priority + ((j + 1) * bucket_width)}[ • ")
          if j == pos
            io.print("--> ")
          else
            io.print("    ")
          end
          io.puts("Bucket #{j}: #{@buckets[j].size} elements")
        end
        nil
      end
    end

    def inspect(io : IO)
      io.print("\n================================================\n")
      io.printf("[%.2f,+∞[ • Top: %d elements", @top_start, @top.size)
      io.printf(", max=%.2f", @top_max) if @top_max
      io.print("\n================================================\n")

      @active_rungs.times do |i|
        rung = @rungs[i]
        io.printf("[%.2f,%.2f[ • ", rung.start_priority, rung.start_priority + ((rung.size - 1) * rung.bucket_width))
        if i == @active_rungs - 1
          io.print "--> "
        else
          io.print "    "
        end

        io.printf("Rung#%d: cur=%.2f (%d elements)\n", i, rung.current_priority, rung.count)

        if i == @active_rungs - 1
          if rung.count < 20*50
            (0...rung.size).each do |j|
              next if rung[j].empty? && j != rung.pos
              io.printf("    ")
              io.printf("[%.2f,%.2f[ • ",
                rung.start_priority + (j * rung.bucket_width),
                rung.start_priority + ((j + 1) * rung.bucket_width))
              if j == rung.pos
                io.printf("--> ")
              else
                io.printf("    ")
              end
              io.printf("Bucket %d: ", j)
              rung[j].each do |ev|
                io.printf("%.2f  ", ev[0])
              end
              io.printf("\n")
            end
          else
            b = Math.max(rung.pos - 20, 0)
            e = Math.min(rung.pos + 20, rung.size)

            io.printf("    ...\n") if b > 0
            (b...e).each do |j|
              io.printf("    ")
              io.printf("[%.2f,%.2f[ • ",
                rung.start_priority + (j * rung.bucket_width),
                rung.start_priority + ((j + 1) * rung.bucket_width))

              if j == rung.pos
                io.printf("--> ")
              else
                io.printf("    ")
              end

              io.printf("Bucket %d: ", j)
              rung[j].each do |ev|
                io.printf("%.2f  ", ev[0])
              end
              io.printf("\n")
            end
            io.printf("    ...\n") if e < rung.size - 1
          end
        end
      end

      io.printf("\n------------------------------------------------\n")

      if @bottom.size > 0
        io.printf("[%.2f,%.2f] • Bottom: %d elements", @bottom.first[0], @bottom.last[0], @bottom.size)
      else
        io.printf("            • Bottom: 0 elements")
      end

      io.printf("\n================================================\n")
      nil
    end
  end
end
