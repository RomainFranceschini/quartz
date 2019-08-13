# :nodoc:
struct Set(T)
  def first
    @hash.first_key
  end

  def last
    @hash.last_key
  end

  def shift
    @hash.shift[0]
  end
end

module Quartz
  # Event set based on a array-based min-heap similar to `BinaryHeap`, but
  # optimized for higher event collision rate.
  #
  # Instead of adding all events in the heap, simultaneous events are gathered
  # and as a set in the heap.
  #
  # To avoid O(n) complexity when deleting an arbitrary element, a map is
  # used to store indices for each event in the event set.
  class HeapSet(T) < PriorityQueue(T)
    private DEFAULT_CAPACITY = 32

    # Returns the number of elements in the heap.
    getter size : Int32

    @capacity : Int32

    def initialize(&comparator : Duration, Duration, Bool -> Int32)
      @comparator = comparator
      @size = 0
      @entries = 0
      @capacity = DEFAULT_CAPACITY

      @heap = Pointer(Tuple(Duration, Set(T))).malloc(@capacity)
      @cache = Hash(Duration, Int32).new
    end

    def initialize(initial_capacity : Int, &comparator : Duration, Duration, Bool -> Int32)
      if initial_capacity < 0
        raise ArgumentError.new "Negative array size: #{initial_capacity}"
      end

      @comparator = comparator
      @size = 0
      @entries = 0
      @capacity = initial_capacity.to_i
      if initial_capacity == 0
        @heap = Pointer(Tuple(Duration, Set(T))).null
      else
        @heap = Pointer(Tuple(Duration, Set(T))).malloc(initial_capacity)
      end
      @cache = Hash(Duration, Int32).new
    end

    def empty? : Bool
      @size == 0
    end

    def clear
      @heap.clear(@entries)
      @cache.clear
      @size = 0
      @entries = 0
      self
    end

    def peek? : T?
      peek { nil }
    end

    def peek : T
      peek { raise "heap is empty." }
    end

    def peek
      @size == 0 ? yield : @heap[1][1].first
    end

    def next_priority : Duration
      next_priority { raise "heap is empty." }
    end

    def next_priority
      @size == 0 ? yield : @heap[1][0]
    end

    def pop : T
      if @size == 0
        raise "heap is empty."
      else
        priority, set = @heap[1]
        @size -= 1
        value = set.shift

        if set.empty?
          @cache[priority] = -1
          delete_at(1)
        end

        value
      end
    end

    def to_slice : Slice(Tuple(Duration, Set(T)))
      (@heap + 1).to_slice(@entries)
    end

    def to_a : Array(Tuple(Duration, Set(T)))
      Array(Tuple(Duration, Set(T))).build(@entries) do |pointer|
        pointer.copy_from(@heap + 1, @entries)
        @entries
      end
    end

    def ==(other : HeapSet) : Bool
      size == other.size && to_slice == other.to_slice
    end

    def ==(other) : Bool
      false
    end

    def inspect(io)
      io << "<" << self.class.name << ": size=" << size.to_s(io) << ", top="
      io << peek.to_s(io) << ">"
      nil
    end

    def delete(priority : Duration, event : T) : T?
      raise "heap is empty" if @size == 0
      index = @cache[priority]
      ev, set = @heap[index]

      @size -= 1
      set.delete(event)

      if set.empty?
        @cache[priority] = -1
        delete_at(index)
      end

      event
    end

    private def delete_at(index) : {Duration, Set(T)}
      value = @heap[index]
      @entries -= 1

      if index <= @entries
        @heap[index] = @heap[@entries + 1]
        @cache[@heap[index][0]] = index

        if index > 1 && @comparator.call(@heap[index][0], @heap[index >> 1][0], false) < 0
          sift_up!(index)
        else
          sift_down!(index)
        end
      end

      value
    end

    def push(priority : Duration, value : T) : self
      @size += 1

      if index = @cache[priority]?
        _, set = @heap[index]
        set.add(value)
      else
        @entries += 1
        check_needs_resize
        @heap[@entries] = {priority, Set(T){value}}
        @cache[priority] = @entries
        sift_up!(@entries)
      end

      self
    end

    private def sift_down!(index)
      loop do
        left = (index << 1)
        break if (left > @size)

        right = left + 1
        min = left

        if right <= @entries && @comparator.call(@heap[right][0], @heap[left][0], false) < 0
          min = right
        end

        if @comparator.call(@heap[min][0], @heap[index][0], false) < 0
          @heap[index], @heap[min] = @heap[min], @heap[index]
          @cache[@heap[index][0]] = index
          @cache[@heap[min][0]] = min
          index = min
        else
          break
        end
      end
    end

    private def sift_up!(index)
      p = index >> 1
      while p > 0 && @comparator.call(@heap[index][0], @heap[p][0], false) < 0
        @heap[p], @heap[index] = @heap[index], @heap[p]
        @cache[@heap[p][0]] = p
        @cache[@heap[index][0]] = index
        index = p
        p = index >> 1
      end
    end

    def heapify!
      index = @entries >> 1
      while index >= 0
        sift_down!(index)
        index -= 1
      end
    end

    private def check_needs_resize
      double_capacity if @entries == @capacity
    end

    private def double_capacity
      resize_to_capacity(@capacity * 2)
    end

    private def resize_to_capacity(capacity)
      @capacity = capacity
      if @heap
        @heap = @heap.realloc(@capacity)
      else
        @heap = Pointer({Duration, Set(T)}).malloc(@capacity)
      end
    end
  end
end
