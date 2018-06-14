module Quartz
  # Event set implemented as an array-based heap.
  #
  # Each inserted elements is given a certain priority, based on the result of
  # the comparison. This is a min-heap, which means retrieving an element will
  # always return the one with the highest priority.
  #
  # To avoid O(n) complexity when deleting an arbitrary element, a map is
  # used to store indices for each element in the event set.
  class BinaryHeap(T) < PriorityQueue(T)
    private DEFAULT_CAPACITY = 32

    # Returns the number of elements in the heap.
    getter size : Int32

    @capacity : Int32

    # Creates a new empty BinaryHeap.
    def initialize(&comparator : Duration, Duration -> Int32)
      @comparator = comparator
      @size = 0
      @capacity = DEFAULT_CAPACITY
      @heap = Pointer(Tuple(Duration, T)).malloc(@capacity)
      @cache = Hash(T, Int32).new
    end

    def initialize(initial_capacity : Int, &comparator : Duration, Duration -> Int32)
      if initial_capacity < 0
        raise ArgumentError.new "Negative array size: #{initial_capacity}"
      end

      @comparator = comparator
      @size = 0
      @capacity = initial_capacity.to_i
      if initial_capacity == 0
        @heap = Pointer(Tuple(Duration, T)).null
      else
        @heap = Pointer(Tuple(Duration, T)).malloc(initial_capacity)
      end
      @cache = Hash(T, Int32).new
    end

    def empty? : Bool
      @size == 0
    end

    def clear
      @heap.clear(@size)
      @cache.clear
      @size = 0
      self
    end

    def peek? : T?
      peek { nil }
    end

    def peek : T
      peek { raise "heap is empty." }
    end

    def peek
      @size == 0 ? yield : @heap[1][1]
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
        delete_at(1)[1]
      end
    end

    def to_slice : Slice(Tuple(Duration, T))
      (@heap + 1).to_slice(@size)
    end

    def to_a : Array(Tuple(Duration, T))
      Array(Tuple(Duration, T)).build(@size) do |pointer|
        pointer.copy_from(@heap + 1, @size)
        @size
      end
    end

    def ==(other : BinaryHeap) : Bool
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

    def delete(priority : Duration, event : T) : T
      raise "heap is empty" if @size == 0
      index = @cache[event]
      @cache[event] = -1
      delete_at(index)[1]
    end

    private def delete_at(index) : {Duration, T}
      value = @heap[index]
      @size -= 1

      if index <= @size
        @heap[index] = @heap[@size + 1]
        @cache[@heap[index][1]] = index

        if index > 1 && @comparator.call(@heap[index][0], @heap[index >> 1][0]) < 0
          sift_up!(index)
        else
          sift_down!(index)
        end
      end

      value
    end

    def push(priority : Duration, value : T) : self
      @size += 1
      check_needs_resize
      @heap[@size] = {priority, value}
      @cache[value] = @size
      sift_up!(@size)
      self
    end

    private def sift_down!(index)
      loop do
        left = (index << 1)
        break if (left > @size)

        right = left + 1
        min = left

        if right <= @size && @comparator.call(@heap[right][0], @heap[left][0]) < 0
          min = right
        end

        if @comparator.call(@heap[min][0], @heap[index][0]) < 0
          @heap[index], @heap[min] = @heap[min], @heap[index]
          @cache[@heap[index][1]] = index
          @cache[@heap[min][1]] = min
          index = min
        else
          break
        end
      end
    end

    private def sift_up!(index)
      p = index >> 1
      while p > 0 && @comparator.call(@heap[index][0], @heap[p][0]) < 0
        @heap[p], @heap[index] = @heap[index], @heap[p]
        @cache[@heap[p][1]] = p
        @cache[@heap[index][1]] = index
        index = p
        p = index >> 1
      end
    end

    def heapify!
      index = @size >> 1
      while index >= 0
        sift_down!(index)
        index -= 1
      end
    end

    private def check_needs_resize
      double_capacity if @size == @capacity
    end

    private def double_capacity
      resize_to_capacity(@capacity * 2)
    end

    private def resize_to_capacity(capacity)
      @capacity = capacity
      if @heap
        @heap = @heap.realloc(@capacity)
      else
        @heap = Pointer({Duration, T}).malloc(@capacity)
      end
    end
  end
end
