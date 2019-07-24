module Quartz
  # A fast O(1) priority queue implementation.
  #
  # See paper: Brown, Randy. 1988. “Calendar Queues: a Fast 0(1) Priority Queue
  # Implementation for the Simulation Event Set Problem.” Communications of the
  # ACM 31 (10): 1220–27. doi:10.1145/63039.63045.
  class CalendarQueue(T) < PriorityQueue(T)
    # Returns the number of events.
    getter size : Int32

    @buckets : Slice(Deque(Tuple(Duration, T)))

    # Lower queue size change threshold
    @shrink_threshold : Int32

    # Upper queue size change threshold
    @expand_threshold : Int32

    # Priority of the last dequeued event
    @last_priority : Duration

    # Extent of a bucket
    @width : Duration

    # Bucket index from which the last event was dequeued
    @last_bucket : Int32

    # Top priority at the top of the last bucket (highest priority that could go
    # into the bucket).
    # The paper advocates to set this variable to one-half than the actual
    # top priority of the bucket for the current year to guard against rounding
    # error. However, as we only use fixed-point data types, we always set it to
    # its real value.
    @bucket_top : Duration

    def initialize(@last_priority = Duration.new(0), bucket_count = 8, @width = Duration.new(Scale::FACTOR), &comparator : Duration, Duration, Bool -> Int32)
      @comparator = comparator
      @size = 0
      @resize_enabled = true
      @buckets = Slice.new(bucket_count) { Deque(Tuple(Duration, T)).new }

      i = @last_priority / @width # virtual bucket
      @last_bucket = (i % bucket_count).to_i32

      @bucket_top = (i + 1) * @width

      # set up queue size change thresholds
      @shrink_threshold = (bucket_count / 2.0 - 2).to_i
      @expand_threshold = (2.0 * bucket_count).to_i
    end

    def inspect(io)
      io << "<" << self.class.name << ": size="
      @size.to_s(io)
      io << ", bucket_width="
      @width.to_s(io)
      io << ", last_priority="
      @last_priority.to_s(io)
      io << ", last_bucket="
      @last_bucket.to_s(io)
      io << ", bucket_top="
      @bucket_top.to_s(io)
      io << ", shrink_threshold="
      @shrink_threshold.to_s(io)
      io << ", expand_threshold="
      @expand_threshold.to_s(io)
      io << ">"
      nil
    end

    def to_s(io)
      io.print("\n================================================\n")
      io.puts "calendar queue: #{@size} events, last:#{@last_priority}, buckets:#{@buckets.size}"
      @buckets.each_with_index do |bucket, i|
        next if bucket.empty?

        io.print("[#{(i * @width)},#{((i + 1) * @width)}[ • ")
        if i == @last_bucket
          io.print("--> ")
        else
          io.print("    ")
        end
        # io.puts("Bucket #{i}: #{@buckets[i].size} elements")
        io.print("Bucket #{i}: {")
        bucket.each do |ev|
          io.print(ev[0])
          io << ", "
        end
        io << '}'
        io.puts
      end
      io.print("================================================\n")
    end

    def print_buckets(le_than : Duration)
      print("\n================================================\n")
      puts "calendar queue: #{@size} events, last:#{@last_priority}, buckets:#{@buckets.size}"
      @buckets.each_with_index do |bucket, i|
        next if bucket.empty?

        # if @comparator.call(le_than, bucket.last[0], true) >= 0
        if i >= @last_bucket - 50 && i <= @last_bucket + 50
          print("[#{(i * @width)},#{((i + 1) * @width)}[ • ")
          if i == @last_bucket
            print("--> ")
          else
            print("    ")
          end

          print("Bucket #{i}: {")
          bucket.each do |ev|
            print(ev[0])
            print ", "
          end
          print '}'
          puts
        end
      end
      print("================================================\n")
    end

    def empty? : Bool
      @size == 0
    end

    def clear
      @size = 0
      @resize_enabled = true
      @last_bucket = 0
      local_init(8, Duration.new(Scale::FACTOR), Duration.new(0))
      self
    end

    def push(priority : Duration, value : T)
      vbucket = (priority / @width).to_i64 # virtual bucket
      i = (vbucket % @buckets.size).to_i   # actual bucket

      bucket = @buckets[i]

      if bucket.empty? || @comparator.call(bucket.last[0], priority, false) > 0
        bucket << {priority, value}
      else
        j = bucket.size - 1
        while @comparator.call(priority, bucket[j][0], false) > 0 && j >= 0
          j -= 1
        end
        bucket.insert(j + 1, {priority, value}) # TODO: optimize! lots of memmoves
      end

      @size += 1

      # double the calendar size if needed
      if @size > @expand_threshold
        resize(2 * @buckets.size)
      end

      self
    end

    def delete(priority : Duration, event : T) : T?
      vbucket = (priority / @width).to_i64 # virtual bucket
      i = (vbucket % @buckets.size).to_i   # actual bucket

      bucket = @buckets[i]
      index = bucket.index({priority, event})
      if index
        item = bucket.delete_at(index)
        @size -= 1

        # halve calendar size if needed
        if @size < @shrink_threshold
          resize(@buckets.size // 2)
        end

        return item[1]
      else
        raise "#{event} scheduled at #{priority} not found"
      end
      nil
    end

    def peek : T
      if @size == 0
        raise "calendar queue is empty."
      else
        unsafe_peek[1]
      end
    end

    def peek? : T?
      if @size == 0
        nil
      else
        unsafe_peek[1]
      end
    end

    def next_priority : Duration
      if @size == 0
        raise "calendar queue is empty."
      else
        unsafe_peek[0]
      end
    end

    private def unsafe_peek : Tuple(Duration, T)
      bucket_top = @bucket_top
      count = 0
      ignore_next_epoch = true

      loop do
        if count > 2
          if ignore_next_epoch
            ignore_next_epoch = false
          else
            raise "ohno"
          end
        end

        i = @last_bucket
        while i < @buckets.size
          bucket = @buckets[i]

          if bucket.size > 0 && @comparator.call(bucket.last[0], bucket_top, ignore_next_epoch) < 0
            # found item to dequeue
            @last_bucket = i
            @bucket_top = bucket_top
            item = bucket.last
            return item
          else
            # prepare to check next bucket or else go to a direct search
            i += 1
            i = 0 if i == @buckets.size
            bucket_top += @width

            break if i == @last_bucket # go to direct search
          end
        end

        # directly search for minimum priority event
        lowest = Duration::INFINITY
        tmp = 0
        @buckets.each_with_index do |bucket, i|
          if bucket.size > 0 && @comparator.call(bucket.last[0], lowest, ignore_next_epoch) < 0
            lowest = bucket.last[0]
            tmp = i
          end
        end
        @last_bucket = tmp
        bucket_top = (lowest / @width + 1).to_i64 * @width

        # resume search at min bucket
        count += 1
      end
    end

    def pop : T
      if @size == 0
        raise "calendar queue is empty."
      else
        unsafe_pop[1]
      end
    end

    def pop? : T?
      if @size == 0
        nil
      else
        unsafe_pop[1]
      end
    end

    private def unsafe_pop : Tuple(Duration, T)
      count = 0
      ignore_next_epoch = true

      loop do
        if count > 2
          if ignore_next_epoch
            ignore_next_epoch = false
          else
            raise "ohno"
          end
        end

        i = @last_bucket
        while i < @buckets.size
          bucket = @buckets[i]

          if bucket.size > 0 && @comparator.call(bucket.last[0], @bucket_top, ignore_next_epoch) < 0
            # found item to dequeue
            item = bucket.pop
            @last_bucket = i
            @last_priority = item[0]
            @size -= 1

            if @size < @shrink_threshold
              resize(@buckets.size // 2)
            end

            return item
          else
            # prepare to check next bucket or else go to a direct search
            i += 1
            i = 0 if i == @buckets.size
            @bucket_top += @width
            break if i == @last_bucket # go to direct search
          end
        end

        # directly search for minimum priority event
        lowest = Duration::INFINITY
        tmp = 0
        @buckets.each_with_index do |bucket, i|
          if bucket.size > 0 && @comparator.call(bucket.last[0], lowest, false) < 0
            lowest = bucket.last[0]
            tmp = i
          end
        end
        @last_bucket = tmp
        @last_priority = lowest
        @bucket_top = (((lowest / @width) + 1).to_i64 * @width + (0.5 * @width))
        # resume search at min bucket
        count += 1
      end
    end

    private def local_init(bucket_count : Int, @width : Duration, @last_priority : Duration)
      @buckets = Slice(Deque(Tuple(Duration, T))).new(bucket_count) { Deque(Tuple(Duration, T)).new }

      i = (@last_priority / @width).to_i64 # virtual bucket
      @last_bucket = (i % bucket_count).to_i32
      @bucket_top = (i + 1) * @width

      # set up queue size change thresholds
      @shrink_threshold = (bucket_count / 2.0 - 2).to_i
      @expand_threshold = (2.0 * bucket_count).to_i
    end

    # Resize buckets to *new_size*.
    def resize(new_size)
      return unless @resize_enabled

      tmp_buckets = @buckets

      bucket_width = new_width # find new bucket width
      local_init(new_size, bucket_width, @last_priority)

      tmp_buckets.each do |bucket|
        @size -= bucket.size
        while !bucket.empty?
          duration, event = bucket.pop
          push(duration, event)
        end
      end
    end

    # Calculates the width to use for buckets
    private def new_width : Duration
      # decides how many queue elements to sample
      return Duration.new(2) if @size < 2

      n = Math.min(
        if @size <= 5
          @size
        else
          5 + (@size // 10)
        end,
        25
      )

      # record variables
      tmp_last_bucket = @last_bucket
      tmp_last_priority = @last_priority
      tmp_bucket_top = @bucket_top

      # dequeue n events from the queue and record their priorities with
      # resize_enabled set to false.
      @resize_enabled = false
      average = Duration.new(0)

      prev_duration = Duration.new(0)
      tmp = StaticArray(Tuple(Duration, T)?, 25).new do |i|
        if i < n # dequeue events to get a test sample
          duration, event = unsafe_pop
          if i > 0 # sum up the differences in time
            average += duration - prev_duration
          end
          prev_duration = duration
          {duration, event}
        else
          nil
        end
      end

      # calculate average separation of sampled events
      average = average / (n - 1)

      # put the first sample back onto the queue
      duration, event = tmp[0].not_nil!
      push(duration, event)

      # recalculate average using only separations smaller than twice the
      # original average
      new_average = Duration.new(0)
      j = 0
      i = 1
      while i < n
        sub = tmp[i].not_nil![0] - tmp[i - 1].not_nil![0]
        if sub < average * 2
          new_average += sub
          j += 1
        end
        # put the remaining samples back onto the queue
        duration, event = tmp[i].not_nil!
        push(duration, event)
        i += 1
      end
      new_average = new_average / j

      # restore variables
      @resize_enabled = true
      @last_bucket = tmp_last_bucket
      @last_priority = tmp_last_priority
      @bucket_top = tmp_bucket_top

      # this is the new width
      if new_average > Duration.new(0)
        new_average * 3.0
      elsif average > Duration.new(0)
        average * 2.0
      else
        Duration.new(2)
      end
    end
  end
end
