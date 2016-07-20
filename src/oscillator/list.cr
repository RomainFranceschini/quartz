module DEVS

  class List(T)
    include Enumerable(T)

    class NoSuchElementError < Exception; end

    getter size
    getter head : Node(T)?
    getter tail : Node(T)?

    class Node(T)
      property data : T
      property next : Node(T)?
      property prev : Node(T)?
      def initialize(@data : T, @next = nil, @prev = nil)
      end
    end

    def initialize
      @head = @tail = nil
      @size = 0
    end

    def clear
      @head = @tail = nil
      @size = 0
    end

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
    def [](index : Int)
      at(index)
    end

    # Returns the element at the given index.
    #
    # Negative indices can be used to start counting from the end of the list.
    # Returns `nil` if trying to access an element outside the list's range.
    def []?(index : Int)
      at(index) { nil }
    end

    # Sets the given value at the given index replacing the old value
    #
    # Negative indices can be used to start counting from the end of the list.
    # Raises `IndexError` if trying to access an element outside the list's range.
    def []=(index : Int, value : T)
      node = node_at(index) { raise IndexError.new }
      node.data = value
    end

    # Returns the element at the given index, if in bounds, otherwise raises `IndexError`.
    def at(index : Int)
      at(index) { raise IndexError.new }
    end

    # Returns the element at the given index, if in bounds, otherwise executes the given block and returns its value.
    def at(index : Int)
      (node_at(index) { yield }).data
    end

    # Returns the node at the given index, if in bounds, otherwise executes the given block and returns its value.
    private def node_at(index : Int)
      index += @size if index < 0
      unless 0 <= index < @size
        yield
      else
        e = nil
        if index < size >> 1
          e = @head
          index.times { |i| e = e.next }
        else
          e = @tail
          (@size-1).downto(index) { |i| e = e.prev }
        end
        e
      end
    end

    # Appends the elements of *other* to `self`, and returns `self`.
    def concat(other : Enumerable(T))
      other.each { |x| push x }
      self
    end

    # Removes the last element in the list.
    def pop
      back = @tail
      return unless back

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

    # Removes the first element in the list.
    def shift
      front = @head
      return unless front

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

    # Pushes the given value on to the end of this list.
    def push(obj : T)
      node = Node.new(obj, nil, nil)
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

    def <<(obj : T)
      push(obj)
      self
    end

    # Prepends objects to the front of self.
    def unshift(obj : T)
      node = Node.new(obj, nil, nil)
      if front = @head
        front.next = node
        node.prev = @head
        @head = node
      else
        @head = @tail = node
      end
      @size += 1
      obj
    end

    # Removes the all or the first occurence of the specified element.
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

    def delete(node : Node(T))
      raise NoSuchElementError.new if @size == 0
      data = node.data

      if @size == 1
        clear
      else
        return shift  if node == @head
        return pop    if node == @tail

        @size -= 1
        pn = node.prev
        nn = node.next
        pn.next = nn if pn
        nn.prev = pn if nn
      end

      data
    end

    # Calls the given block once for each element in self, passing that
    # element as a parameter.
    def each
      node = @head
      while node
        yield node.data
        node = node.next
      end
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

    def reverse_each
      node = @tail
      while node
        yield node.data
        node = node.prev
      end
    end
  end
end
