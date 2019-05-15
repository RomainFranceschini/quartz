module Quartz
  # A List (implementation of a doubly linked list) is a collection of objects
  # of type T that behaves much like an Array.
  #
  # All of the operations perform as could be expected for a doubly-linked list.
  # Operations that index into the list will traverse the list from the
  # beginning or the end, whichever is closer to the specified index.
  #
  # This structure allows for efficient insertion or removal of elements from
  # any position since it returns a `List::Node` from all insert operations
  # (`#push`, `#insert`, `#unshift`) in order to be reused in `#delete`.
  #
  # TODO : #insert_before(node)
  class List(T)
    include Enumerable(T)
    include Comparable(List)
    include Iterable(T)

    class NoSuchElementError < Exception; end

    getter size
    @head : Node(T)?
    @tail : Node(T)?

    class Node(T)
      include Comparable(Node)

      property data : T
      property next : Node(T)?
      property prev : Node(T)?

      def initialize(@data : T, @next = nil, @prev = nil)
      end

      def_equals @data

      def ==(other)
        false
      end

      delegate hash, to: @data

      def inspect(io)
        @data.inspect(io)
      end

      def to_s(io)
        @data.to_s(io)
      end
    end

    # Creates a new empty List
    def initialize
      @head = @tail = nil
      @size = 0
    end

    # Creates a new List of the given size filled with the same value in each
    # position.
    #
    # ```
    # List.new(3, 'a') # => List{'a', 'a', 'a'}
    # ```
    def initialize(size : Int, value : T)
      if size < 0
        raise ArgumentError.new("negative list size: #{size}")
      end
      @size = 0
      size.times { |i| push(value) }
    end

    # Creates a new List of the given size and invokes the block once for each
    # index of the list, assigning the block's value in that index.
    #
    # ```
    # List.new(3) { |i| (i + 1) ** 2 } # => List{1, 4, 9}
    # ```
    def initialize(size : Int, &block : Int32 -> T)
      if size < 0
        raise ArgumentError.new("negative list size: #{size}")
      end
      @size = 0
      size.times { |i| push(yield(i)) }
    end

    # Creates a new List that copies its items from an Array.
    #
    # ```
    # List.new([1, 2, 3]) # => List{1, 2, 3}
    # ```
    def self.new(array : Array(T))
      List(T).new(array.size) { |i| array[i] }
    end

    # Equality. Returns *true* if each element in `self` is equal to each
    # corresponding element in *other*.
    # ```
    # list = List{2, 3}
    # list.unshift
    # list == List{1, 2, 3} # => true
    # list == List{2, 3}    # => false
    # ```
    def ==(other : List)
      equals?(other) { |lhs, rhs| lhs == rhs }
    end

    # :nodoc:
    def ==(other)
      false
    end

    # Concatenation. Returns a new List built by concatenating two lists
    # together to create a third. The type of the new list is the union of the
    # types of both the other lists.
    def +(other : List(U)) forall U
      List(T | U).new.concat(self).concat(other)
    end

    # :nodoc:
    def +(other : List(T))
      dup.concat other
    end

    # Determines if `self` equals *other* according to a comparison
    # done by the given block.
    #
    # If `self`'s size is the same as *other*'s size, this method yields
    # elements from `self` and *other* in tandem: if the block returns true
    # for all of them, this method returns *true*. Otherwise it returns *false*.
    def equals?(other : List)
      return false if @size != other.size
      it = other.each
      each do |item|
        return false unless yield(item, it.next.as(T))
      end
      true
    end

    def clear
      @head = @tail = nil
      @size = 0
    end

    # Returns true if this deque has 0 items.
    def empty?
      @size == 0
    end

    # Returns the first element of the list, or nil if the list is empty
    def first? : T?
      @head.try &.data
    end

    # Returns the first element of the list. Raises if empty.
    def first : T
      raise NoSuchElementError.new if @size == 0
      @head.not_nil!.data
    end

    # Returns the first element of the list, or nil if the list is empty
    def last? : T?
      @tail.try &.data
    end

    # Returns the first element of the list. Raises if empty.
    def last : T
      raise NoSuchElementError.new if @size == 0
      @tail.not_nil!.data
    end

    # Returns the element at the given `index`.
    #
    # Negative indices can be used to start counting from the end of the list.
    # Raises `IndexError` if trying to access an element outside the list's range.
    @[AlwaysInline]
    def [](index : Int)
      at(index)
    end

    # Returns the element at the given index.
    #
    # Negative indices can be used to start counting from the end of the list.
    # Returns `nil` if trying to access an element outside the list's range.
    @[AlwaysInline]
    def []?(index : Int)
      at(index) { nil }
    end

    # Sets the given value at the given index replacing the old value
    #
    # Negative indices can be used to start counting from the end of the list.
    # Raises `IndexError` if trying to access an element outside the list's range.
    @[AlwaysInline]
    def []=(index : Int, value : T)
      node = node_at(index) { raise IndexError.new }
      node.data = value
    end

    # Insert a new item before the item at `index`.
    #
    # ```
    # l = List{0, 1, 2}
    # l.insert_at(1, 7) # => List{0, 7, 1, 2}
    # ```
    def insert(index : Int, value : T)
      index += @size + 1 if index < 0

      return unshift(value) if index == 0
      return push(value) if index == @size

      node = node_at(index) { raise IndexError.new }
      new_node = Node(T).new(value, node, node.try &.prev)
      new_node.prev.not_nil!.next = new_node
      new_node.next.not_nil!.prev = new_node
      @size += 1
      new_node
    end

    # Returns the element at the given index, if in bounds, otherwise raises `IndexError`.
    @[AlwaysInline]
    def at(index : Int)
      at(index) { raise IndexError.new }
    end

    # Returns the element at the given index, if in bounds, otherwise executes the given block and returns its value.
    @[AlwaysInline]
    def at(index : Int)
      (node_at(index) { yield }).try &.data
    end

    # Returns the node at the given index, if in bounds, otherwise executes the given block and returns its value.
    private def node_at(index : Int)
      index += @size if index < 0
      unless 0 <= index < @size
        yield
      else
        if index < size >> 1
          e = @head.not_nil!
          index.times { |i| e = e.next.not_nil! }
          e
        else
          e = @tail.not_nil!
          (@size - 1).downto(index + 1) { |i| e = e.prev.not_nil! }
          e
        end
      end
    end

    # Returns a new List that has this list's elements cloned.
    # That is, it returns a deep copy of this list.
    #
    # Use `#dup` if you want a shallow copy.
    def clone
      list = List(T).new
      each { |item| list.push(item.clone.as(T)) }
      list
    end

    # Returns a new List that has exactly this list's elements.
    # That is, it returns a shallow copy of this list.
    def dup
      list = List(T).new
      each { |item| list.push(item.as(T)) }
      list
    end

    # Appends the elements of *other* to `self`, and returns `self`.
    def concat(other : Enumerable(T))
      other.each { |x| push x }
      self
    end

    def hash(hasher)
      hasher = @size.hash(hasher)
      each do |elem|
        hasher = elem.hash(hasher)
      end
      hasher
    end

    # Removes and returns the last item. Raises `NoSuchElementError` if empty.
    #
    # ```
    # l = List{1, 2, 3}
    # l.pop # => 3
    # # l == List{1, 2}
    # ```
    @[AlwaysInline]
    def pop
      pop { raise NoSuchElementError.new }
    end

    # Removes and returns the last item, if not empty, otherwise executes the
    # given block and returns its value.
    def pop
      back = @tail
      return yield unless back

      data = back.data

      if @size == 1
        clear
      else
        @size -= 1
        if back = @tail = back.prev
          back.next = nil
        end
      end
      data
    end

    # Removes and returns the last item, if not empty, otherwise `nil`.
    @[AlwaysInline]
    def pop?
      pop { nil }
    end

    # Removes the last `n` (at most) items in the list.
    def pop(n : Int)
      if n < 0
        raise ArgumentError.new("can't pop negative count")
      end
      n = Math.min(n, @size)
      n.times { pop }
      nil
    end

    # Removes and returns the first item. Raises `NoSuchElementError` if empty.
    #
    # ```
    # l = List{1, 2, 3}
    # l.shift # => 1
    # # l == List{2, 3} -> true
    # ```
    @[AlwaysInline]
    def shift
      shift { raise NoSuchElementError.new }
    end

    # Removes the first element in the list, if not empty, otherwise executes
    # the given block and returns its value.
    def shift
      front = @head
      return yield unless front

      data = front.data

      if @size == 1
        clear
      else
        @size -= 1
        if front = @head = front.next
          front.prev = nil
        end
      end
      data
    end

    # Removes and returns the first item, if not empty, otherwise `nil`.
    @[AlwaysInline]
    def shift?
      shift { nil }
    end

    # Removes the first `n` (at most) items in the list.
    def shift(n : Int)
      if n < 0
        raise ArgumentError.new("can't shift negative count")
      end
      n = Math.min(n, @size)
      n.times { shift }
      nil
    end

    # Swaps the items at the indices `i` and `j`.
    def swap(i, j)
      self[i], self[j] = self[j], self[i]
      self
    end

    # Rotates this list in place so that the element at `n` becomes first.
    #
    # For positive `n`, equivalent to `n.times { push(shift) }`.
    # For negative `n`, equivalent to `(-n).times { unshift(pop) }`.
    def rotate!(n : Int = 1)
      # Turn `n` into an equivalent index in range -size/2 .. size/2
      half = @size // 2
      if n.abs >= half
        n = (n + half) % @size - half
      end
      while n > 0
        push(shift)
        n -= 1
      end
      while n < 0
        n += 1
        unshift(pop)
      end
    end

    # Returns an Array (shallow copy) that contains all the items of this list.
    def to_a
      ary = Array(T).new(@size)
      each { |x| ary << x }
      ary
    end

    def inspect(io : IO)
      to_s io
    end

    def to_s(io : IO)
      executed = exec_recursive(:inspect) do
        io << "List{"
        join ", ", io, &.inspect(io)
        io << "}"
      end
      io << "List{...}" unless executed
      nil
    end

    # Pushes the given value on to the end of this list.
    # ```
    # l = List{1, 2}
    # l.push 3 # => List{1, 2, 3}
    # ```
    def push(obj : T)
      node = Node(T).new(obj, nil, nil)
      if back = @tail
        back.next = node
        node.prev = @tail
        @tail = node
      else
        @head = @tail = node
      end
      @size += 1
      node
    end

    # Pushes the given value on to the end of this list. Returns `self` instead
    # of the created node.
    def <<(obj : T)
      push(obj)
      self
    end

    # Prepends objects to the front of the list.
    def unshift(obj : T)
      node = Node(T).new(obj, nil, nil)
      if front = @head
        front.prev = node
        node.next = front
        @head = node
      else
        @head = @tail = node
      end
      @size += 1
      node
    end

    # Removes all items or the first occurence that are equal to *obj*.
    #
    # ```
    # l = List{"a", "b", "b", "b", "c", "c"}
    # l.delete("b")
    # l # => List{"a", "c", "c"}
    # l.delete("c", all: false)
    # l # => List{"a", "c"}
    # ```
    def delete(obj : T, all = true)
      found = false
      node = @head
      while node
        if node.data == obj
          found = true
          next_node = node.next
          delete(node)
          node = next_node
          break unless all
        else
          node = node.next
        end
      end
      found
    end

    # Delete the item that is present at the `index`.
    # Raises `IndexError` if trying to delete an element outside the list's
    # range.
    #
    # ```
    # a = List{1, 2, 3}
    # a.delete_at(1) # => List{1, 3}
    # ```
    @[AlwaysInline]
    def delete_at(index : Int)
      delete(node_at(index) { raise IndexError.new })
    end

    def delete(node : Node(T))
      raise NoSuchElementError.new if @size == 0
      data = node.data

      if @size == 1
        clear
      else
        return shift if node == @head
        return pop if node == @tail

        @size -= 1
        pn = node.prev
        nn = node.next
        pn.next = nn if pn
        nn.prev = pn if nn
      end

      data
    end

    # Yields each item in this list, from first to last.
    #
    # Do not modify the list while using this variant of `each`!
    def each
      node = @head
      while node
        yield node.data
        node = node.next
      end
    end

    # Gives an iterator over each item in this list, from first to last.
    def each
      ItemIterator.new(@head)
    end

    # Calls the given block once for each element in self, passing that
    # element as a parameter.
    def each_node
      node = @head
      while node
        yield node
        node = node.next
      end
    end

    # Yields each item in this list, from last to first.
    #
    # Do not modify the list while using `reverse_each`!
    def reverse_each
      node = @tail
      while node
        yield node.data
        node = node.prev
      end
    end

    # :nodoc:
    class ItemIterator(T)
      include Iterator(T)

      @head : List::Node(T)?
      @node : List::Node(T)?

      def initialize(@head : List::Node(T)?)
        @node = @head
      end

      def next
        if node = @node
          value = node.data
          @node = node.next
          value
        else
          stop
        end
      end

      def rewind
        @node = @head
        self
      end
    end
  end
end
