module Quartz
  # A fast O(1) priority queue implementation
  class CalendarQueue(T) < PriorityQueue(T)
    include Comparable(CalendarQueue)

    getter size

    @buckets : Slice(Deque(Tuple(Duration, T)))

    @shrink_threshold : Int64
    @expand_threshold : Int64
    @last_priority : Duration
    @bucket_top : Duration
    @width : Duration

    def initialize(start_priority = Duration.new(0), bucket_count = 2, bucket_width = Duration.new(2), &comparator : Duration, Duration, Bool -> Int32)
      @comparator = comparator
      @size = 0
      @resize_enabled = true

      # the bucket index from which the last event was dequeued
      @last_bucket = 0
      # the priority at the top of that bucket (highest priority that could go
      # into the bucket)
      @bucket_top = Duration.new(0)
      # the priority of the last event dequeued
      @last_priority = Duration.new(0)

      @width = bucket_width
      @buckets = Slice.new(bucket_count) { Deque(Tuple(Duration, T)).new }
      @last_priority = start_priority
      i = start_priority / bucket_width # virtual bucket
      @last_bucket = (i % bucket_count).to_i
      @bucket_top = (i + 1) * bucket_width + 0.5 * bucket_width
      # set up queue size change thresholds
      @shrink_threshold = (bucket_count / 2.0 - 2).to_i64
      @expand_threshold = (2.0 * bucket_count).to_i64
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

    def empty? : Bool
      @size == 0
    end

    def clear
      @size = 0
      @resize_enabled = true
      @last_bucket = 0
      @bucket_top = Duration.new(0)
      @last_priority = Duration.new(0)
      local_init(2, Duration.new(2), Duration.new(0))
      self
    end

    def push(priority : Duration, value : T)
      vbucket = (priority / @width).to_i # virtual bucket
      i = vbucket % @buckets.size        # actual bucket

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
      vbucket = (priority / @width).to_i # virtual bucket
      i = vbucket % @buckets.size        # actual bucket

      bucket = @buckets[i]
      index = bucket.index({priority, event})
      if index
        item = bucket.delete_at(index)
        @size -= 1

        # halve calendar size if needed
        if @size < @shrink_threshold
          resize(@buckets.size / 2)
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

    def next_priority
      if @size == 0
        raise "calendar queue is empty."
      else
        unsafe_peek[0]
      end
    end

    private def unsafe_peek : Tuple(Duration, T)
      last_bucket = @last_bucket
      last_priority = @last_priority
      bucket_top = @bucket_top

      loop do
        i = last_bucket
        while i < @buckets.size
          bucket = @buckets[i]

          if bucket.size > 0 && @comparator.call(bucket.last[0], bucket_top, true) < 0
            # found item to dequeue
            item = bucket.last
            last_bucket = i
            last_priority = item[0]

            return item
          else
            # prepare to check next bucket or else go to a direct search
            i += 1
            i = 0 if i == @buckets.size
            bucket_top += @width

            break if i == last_bucket # go to direct search
          end
        end

        # directly search for minimum priority event
        lowest = Duration::INFINITY
        tmp = 0
        @buckets.each_with_index do |bucket, i|
          if bucket.size > 0 && @comparator.call(bucket.last[0], lowest, true) < 0
            lowest = bucket.last[0]
            tmp = i
          end
        end
        last_bucket = tmp
        last_priority = lowest
        bucket_top = (((lowest / @width) + 1).to_i * @width + (0.5 * @width))

        # resume search at min bucket
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
      last_bucket = @last_bucket
      last_priority = @last_priority
      bucket_top = @bucket_top

      loop do
        i = last_bucket
        while i < @buckets.size
          bucket = @buckets[i]

          if bucket.size > 0 && @comparator.call(bucket.last[0], bucket_top, true) < 0
            # found item to dequeue
            item = bucket.pop
            last_bucket = i
            last_priority = item[0]
            @size -= 1

            @last_bucket = last_bucket
            @last_priority = last_priority
            @bucket_top = bucket_top

            if @size < @shrink_threshold
              resize(@buckets.size / 2)
            end

            return item
          else
            # prepare to check next bucket or else go to a direct search
            i += 1
            i = 0 if i == @buckets.size
            bucket_top += @width
            break if i == last_bucket # go to direct search
          end
        end

        # directly search for minimum priority event
        lowest = Duration::INFINITY
        tmp = 0
        @buckets.each_with_index do |bucket, i|
          if bucket.size > 0 && @comparator.call(bucket.last[0], lowest, true) < 0
            lowest = bucket.last[0]
            tmp = i
          end
        end
        last_bucket = tmp
        last_priority = lowest
        bucket_top = (((lowest / @width) + 1) * @width + (0.5 * @width))
        # resume search at min bucket
      end
    end

    private def local_init(bucket_count : Int, bucket_width : Duration, start_priority : Duration)
      @width = bucket_width

      @buckets = Slice(Deque(Tuple(Duration, T))).new(bucket_count) { Deque(Tuple(Duration, T)).new }

      @last_priority = start_priority
      i = (start_priority / bucket_width).to_i # virtual bucket
      @last_bucket = (i % bucket_count).to_i
      @bucket_top = (i + 1) * bucket_width + 0.5 * bucket_width

      # set up queue size change thresholds
      @shrink_threshold = (bucket_count / 2.0 - 2).to_i64
      @expand_threshold = (2.0 * bucket_count).to_i64
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

      n = if @size <= 5
            @size
          else
            5 + (@size / 10).to_i
          end
      n = 25 if n > 25

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
