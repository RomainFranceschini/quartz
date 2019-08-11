module Quartz
  # Event set implemented as a Fibonacci Heap, as described by Fredman and
  # Tarjan.
  #
  # Structured as a collection of root trees that are min-heap ordered, and
  # internally represented as a circular, doubly-linked list.
  class FibonacciHeap(T) < PriorityQueue(T)
    # Returns the number of elements in the heap.
    getter size : Int32

    # Reference to the min element in the heap.
    @min_node : Node(T)?

    @degrees : Pointer(Node(T)?)

    def initialize(&comparator : Duration, Duration, Bool -> Int32)
      @comparator = comparator
      @size = 0
      @min_node = nil
      @degrees_capa = 0
      @degrees = Pointer(Node(T)?).null
      @cache = Hash(T, Node(T)).new
    end

    # Whether the event set is empty or not.
    def empty? : Bool
      @min_node.nil?
    end

    # Clears `self`.
    def clear
      @cache.clear
      @min_node = nil
      @size = 0
    end

    # Insert the given *value* with the specified *priority* into `self`..
    def push(priority : Duration, value : T)
      node = Node(T).new(priority, value)
      raise "Element #{value} is already inserted." if @cache.has_key?(value)
      @cache[value] = node
      @min_node = merge(@min_node, node)
      @size += 1
    end

    # Merge the two given lists into one circular linked list.
    #
    # Given two disjoint lists *a* and *b*:
    #  +----+     +----+     +----+
    #  |    |--N->|one |--N->|    |
    #  |    |<-P--|    |<-P--|    |
    #  +----+     +----+     +----+
    #
    #  +----+     +----+     +----+
    #  |    |--N->|two |--N->|    |
    #  |    |<-P--|    |<-P--|    |
    #  +----+     +----+     +----+
    #
    #  Merge
    #
    #  +----+     +----+     +----+---+
    #  |    |--N->|one |     |    |   |
    #  |    |<-P--|    |     |    |<+ |
    #  +----+     +----+<-\  +----+ | |
    #                   \  P        | |
    #                    N  \       N |
    #  +----+     +----+  \->+----+ | |
    #  |    |--N->|two |     |    | | |
    #  |    |<-P--|    |     |    | | P
    #  +----+     +----+     +----+ | |
    #               ^ |             | |
    #               | +-------------+ |
    #               +-----------------+
    #
    # Returns the smallest node of the resulting list.
    private def merge(a : Node(T)?, b : Node(T)?, rhs_in_current_epoch : Bool = false) : Node(T)?
      if a && b
        tmp = a.next
        a.next = b.next
        a.next.prev = a
        b.next = tmp
        b.next.prev = b

        # Return the smaller node
        @comparator.call(a.priority, b.priority, rhs_in_current_epoch) < 0 ? a : b
      elsif a && !b
        a
      elsif !a && b
        b
      else
        nil
      end
    end

    # Dequeue and return the min element.
    def pop : T
      if min = @min_node
        @cache.delete(min.value)
        @size -= 1

        # Unlink min node from its children since they're about to become roots.
        min.each_child { |child| child.parent = nil }

        # Set new min node by removing min to be dequeued and setting its
        # children as roots.
        @min_node = if min.strayed? # min is the only element of the root list.
                      min.children  # new root list is simply min's children.
                    else
                      list = min.next                       # Arbitrary root list start.
                      remove(min)                           # Remove min from root list.
                      @min_node = merge(list, min.children) # Merge new list with the children of the dequeued node.
                    end

        consolidate if @min_node

        min.value
      else
        raise "heap is empty"
      end
    end

    # Detach the given *node* from its siblings.
    private def remove(node : Node(T))
      p = node.prev
      n = node.next

      p.next = n
      n.prev = p

      node.next = node
      node.prev = node
    end

    # Returns a `Slice` of nodes which is used by the `#consolidate` method.
    #
    # Internally (re)-allocates a pointer for performance reasons, which is
    # re-used to build the get a slice of nodes to track trees of each degree. An entry at given
    # index returned slice.
    private def degrees_slice : Slice(Node(T)?)
      max_degree = Math.log2(@size).ceil.to_i + 1

      if @degrees.null?
        @degrees = Pointer(Node(T)?).malloc(max_degree) { nil }
      elsif max_degree > @degrees_capa                              # increase capacity if needed
        new_capa = Math.max(max_degree, @degrees_capa*2)            # double capacity or use what's needed
        @degrees = @degrees.realloc(new_capa)                       # realloc up to new capacity
        @degrees.clear(@degrees_capa)                               # clears old contents
        (@degrees_capa...max_degree).each { |i| @degrees[i] = nil } # init new slots
        @degrees_capa = new_capa                                    # sets new capacity
      else                                                          # halve if needed
        half = @degrees_capa // 2
        if max_degree < half
          @degrees = @degrees.realloc(half)
          @degrees_capa = half
        end
        @degrees.clear(max_degree)
      end

      # Returns a slice sized based on the maximum degree.
      @degrees.to_slice(max_degree)
    end

    # Converts a circular doubly-linked list starting from given *node* to
    # an array.
    #
    # Internally re-use a reference to an array to populate nodes, for
    # performance reasons.
    private def node_and_siblings_list(node : Node(T)?) : Array(Node(T))
      ary = @node_list ||= Array(Node(T)).new
      ary.clear unless ary.empty?

      if start = node
        loop do
          ary << node
          node = node.next
          break if node == start
        end
      end

      ary
    end

    # Consolidates the heap by coalescing all roots, resulting in one tree of
    # each degree.
    private def consolidate
      # Get a slice of nodes to track trees of each degree. An entry at given
      # index is either `nil` or the unique tree of degree *i*.
      degrees = degrees_slice

      # builds a list of roots to iterate over.
      nodes = node_and_siblings_list(@min_node)

      nodes.each do |x|
        d = x.degree
        while y = degrees[d]
          if @comparator.call(x.priority, y.priority, false) > 0
            x, y = y, x
          end
          connect(y, x)
          degrees[d] = nil
          d += 1
        end

        degrees[d] = x
      end

      # Set root trees.
      @min_node = nil
      degrees.each do |node|
        next if node.nil?
        # remove siblings before merge
        node.next = node
        node.prev = node
        @min_node = merge(@min_node, node)
      end
    end

    private def connect(max : Node(T), min : Node(T))
      remove(max)
      min.children = merge(max, min.children)
      min.degree += 1
      max.parent = min
      max.marked = false
    end

    def peek : T
      if min = @min_node
        min.value
      else
        raise "heap is empty"
      end
    end

    def peek? : T?
      if min = @min_node
        min.value
      else
        nil
      end
    end

    def next_priority : Duration
      if min = @min_node
        min.priority
      else
        raise "heap is empty"
      end
    end

    def delete(priority : Duration, value : T) : T
      node = @cache[value]
      decrease_key(node, Duration.new(Duration::MULTIPLIER_MAX, Scale.new(-128_i8)))

      if @min_node != node
        raise "Invalid state: min node (#{@min_node}) should eq #{node}"
      end

      pop
    end

    def inspect(io)
      io << "<FibonacciHeap: roots="
      node_and_siblings_list(@min_node).inspect(io)
      io << '>'
    end

    private def decrease_key(node : Node(T), new_priority : Duration)
      if @comparator.call(node.priority, new_priority, true) <= 0
        raise "Invalid priority: #{new_priority} is greater than current priority #{node.priority}"
      end

      node.priority = new_priority

      # If the given node has a higher priority than its parent, cut it.
      if (parent = node.parent) && @comparator.call(parent.priority, node.priority, true) >= 0
        cut(node, parent, true)
        cascading_cut(parent)
      end

      if min = @min_node
        # If the new priority is the highest, sets node as the min node.
        if @comparator.call(min.priority, node.priority, true) >= 0
          @min_node = node
        end
      else
        @min_node = node
      end
    end

    # Cuts given *node* from its parent.
    private def cut(node : Node(T), parent : Node(T), node_in_current_epoch : Bool = false)
      node.parent = nil
      parent.degree -= 1
      parent.children = node.strayed? ? nil : node.next
      remove(node)

      @min_node = merge(@min_node, node, node_in_current_epoch)
      node.marked = false
    end

    # Recursively cuts given *node* from its parent if it is marked, or mark
    # it otherwise.
    #
    # Note: this operation has been de-recursivated for performance reasons.
    private def cascading_cut(node : Node(T))
      while parent = node.parent
        if node.marked?
          cut(node, parent)
          node = parent
        else
          node.marked = true
          break
        end
      end
    end

    private class Node(T)
      getter value : T
      property priority : Duration
      property parent : Node(T)?
      property? marked : Bool
      property degree : Int32
      property prev : Node(T)
      property next : Node(T)

      property children : Node(T)?

      def initialize(@priority : Duration, @value : T, @parent = nil)
        @children = nil
        @marked = false
        @degree = 0

        @prev = uninitialized Node(T)
        @next = uninitialized Node(T)

        @prev = self
        @next = self
      end

      # Whether the node is isolated (i.e. has not siblings).
      def strayed? : Bool
        self == @next
      end

      # Iterate over children
      def each_child
        if node = @children
          loop do
            yield node
            node = node.next
            break if node == @children
          end
        end
      end

      def inspect(io)
        io << '{'
        @priority.to_s(io)
        io << ','
        @value.to_s(io)
        io << ", degree:"
        @degree.to_s(io)
        io << '}'
      end
    end
  end
end
