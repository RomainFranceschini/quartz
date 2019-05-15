require "./spec_helper"

private class ListTester
  @list : List(Int32)
  @array : Array(Int32)
  @i : Int32
  @c : Array(Int32) | List(Int32) | Nil

  def initialize
    @list = List(Int32).new
    @array = Array(Int32).new
    @i = 1
  end

  def step
    @c = @list
    yield
    @c = @array
    yield
    @list.to_a.should eq(@array)
    @i += 1
  end

  getter i

  def c
    @c.not_nil!
  end

  def test
    with self yield
  end
end

private alias RecursiveList = List(RecursiveList)

describe "List" do
  describe "implementation" do
    it "works the same as array" do
      ListTester.new.test do
        step { c.unshift i }
        step { c.pop }
        step { c.push i }
        step { c.shift }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.pop }
        step { c.shift }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.insert(1, i) }
        step { c.insert(0, i) }
        step { c.insert(17, i) }
        step { c.insert(14, i) }
        step { c.insert(10, i) }
        step { c.insert(10, i) }
      end
    end

    it "works the same as array when inserting at 1/8 size and deleting at 3/4 size" do
      ListTester.new.test do
        1000.times do
          step { c.insert(c.size // 8, i) }
        end
        1000.times do
          step { c.delete_at(c.size * 3 // 4) }
        end
      end
    end

    it "works the same as array when inserting at 3/4 size and deleting at 1/8 size" do
      ListTester.new.test do
        1000.times do
          step { c.insert(c.size * 3 // 4, i) }
        end
        1000.times do
          step { c.delete_at(c.size // 8) }
        end
      end
    end

    describe "new" do
      it "creates with default value" do
        list = List.new(5, 3)
        list.should eq(List{3, 3, 3, 3, 3})
      end

      it "creates with default value in block" do
        list = List(Int32).new(5) { |i| i * 2 }
        list.should eq(List{0, 2, 4, 6, 8})
      end

      it "creates from an array" do
        list = List(Int32).new([1, 2, 3, 4, 5])
        list.should eq(List{1, 2, 3, 4, 5})
      end

      it "raises on negative count" do
        expect_raises(ArgumentError, "negative list size") do
          List.new(-1, 3)
        end
      end
    end

    describe "==" do
      it "compares empty" do
        List(Int32).new.should eq(List(Int32).new)
        List{1}.should_not eq(List(Int32).new)
        List(Int32).new.should_not eq(List{1})
      end

      it "compares elements" do
        List{1, 2, 3}.should eq(List{1, 2, 3})
        List{1, 2, 3}.should_not eq(List{3, 2, 1})
      end

      it "compares other" do
        a = List{1, 2, 3}
        b = List{1, 2, 3}
        c = List{1, 2, 3, 4}
        d = List{1, 2, 4}
        (a == b).should be_true
        (b == c).should be_false
        (a == d).should be_false
      end
    end

    describe "+" do
      it "does +" do
        a = List{1, 2, 3}
        b = List{4, 5}
        c = a + b
        c.size.should eq(5)
        0.upto(4) { |i| c[i].should eq(i + 1) }
      end

      it "does + with different types" do
        a = List{1, 2, 3}
        a += List{"hello"}
        a.should eq(List{1, 2, 3, "hello"})
      end
    end

    describe "[]" do
      it "gets on positive index" do
        List{1, 2, 3}[1].should eq(2)
      end

      it "gets on negative index" do
        List{1, 2, 3}[-1].should eq(3)
      end

      it "gets nilable" do
        List{1, 2, 3}[2]?.should eq(3)
        List{1, 2, 3}[3]?.should be_nil
      end

      it "same access by at" do
        List{1, 2, 3}[1].should eq(List{1, 2, 3}.at(1))
      end
    end

    describe "[]=" do
      it "sets on positive index" do
        a = List{1, 2, 3}
        a[1] = 4
        a[1].should eq(4)
      end

      it "sets on negative index" do
        a = List{1, 2, 3}
        a[-1] = 4
        a[2].should eq(4)
      end
    end

    it "does clear" do
      a = List{1, 2, 3}
      a.clear
      a.should eq(List(Int32).new)
    end

    it "does clone" do
      x = {1 => 2}
      a = List{x}
      b = a.clone
      b.should eq(a)
      a.should_not be(b)
      a[0].should_not be(b[0])
    end

    describe "concat" do
      it "concats list" do
        a = List{1, 2, 3}
        a.concat(List{4, 5, 6})
        a.should eq(List{1, 2, 3, 4, 5, 6})
      end

      it "concats large lists" do
        a = List{1, 2, 3}
        a.concat((4..1000).to_a)
        a.should eq(List.new((1..1000).to_a))
      end

      it "concats enumerable" do
        a = List{1, 2, 3}
        a.concat((4..1000))
        a.should eq(List.new((1..1000).to_a))
      end
    end

    describe "delete" do
      it "deletes many" do
        a = List{1, 2, 3, 1, 2, 3}
        a.delete(2).should be_true
        a.should eq(List{1, 3, 1, 3})
      end

      it "delete not found" do
        a = List{1, 2}
        a.delete(4).should be_false
        a.should eq(List{1, 2})
      end
    end

    describe "delete_at" do
      it "deletes positive index" do
        a = List{1, 2, 3, 4, 5}
        a.delete_at(3).should eq(4)
        a.should eq(List{1, 2, 3, 5})
      end

      it "deletes negative index" do
        a = List{1, 2, 3, 4, 5}
        a.delete_at(-4).should eq(2)
        a.should eq(List{1, 3, 4, 5})
      end

      it "deletes out of bounds" do
        a = List{1, 2, 3, 4}
        expect_raises IndexError do
          a.delete_at(4)
        end
      end
    end

    it "does dup" do
      x = {1 => 2}
      a = List{x}
      b = a.dup
      b.should eq(List{x})
      a.should_not be(b)
      a[0].should be(b[0])
      b << {3 => 4}
      a.should eq(List{x})
    end

    describe "empty" do
      it "is empty" do
        (List(Int32).new.empty?).should be_true
      end

      it "is not empty" do
        List{1}.empty?.should be_false
      end
    end

    it "does equals? with custom block" do
      a = List{1, 3, 2}
      b = List{3, 9, 4}
      c = List{5, 7, 3}
      d = List{1, 3, 2, 4}
      f = ->(x : Int32, y : Int32) { (x % 2) == (y % 2) }
      a.equals?(b, &f).should be_true
      a.equals?(c, &f).should be_false
      a.equals?(d, &f).should be_false
    end

    describe "first" do
      it "gets first when non empty" do
        a = List{1, 2, 3}
        a.first.should eq(1)
      end

      it "raises when empty" do
        expect_raises List::NoSuchElementError do
          List(Int32).new.first
        end
      end
    end

    describe "first?" do
      it "gets first? when non empty" do
        a = List{1, 2, 3}
        a.first?.should eq(1)
      end

      it "gives nil when empty" do
        List(Int32).new.first?.should be_nil
      end
    end

    it "does hash" do
      a = List{1, 2, List{3}}
      b = List{1, 2, List{3}}
      a.hash.should eq(b.hash)
    end

    describe "insert" do
      it "returns a node" do
        a = List{1, 3, 4}
        a.insert(1, 2).should be_a(List::Node(Int32))
      end

      it "inserts with positive index" do
        a = List{1, 3, 4}
        expected = List{1, 2, 3, 4}
        a.insert(1, 2)
        a.should eq(expected)
      end

      it "inserts with negative index" do
        a = List{1, 2, 3}
        expected = List{1, 2, 3, 4}
        a.insert(-1, 4)
        a.should eq(expected)
      end

      it "inserts with negative index (2)" do
        a = List{1, 2, 3}
        expected = List{4, 1, 2, 3}
        a.insert(-4, 4)
        a.should eq(expected)
      end

      it "inserts out of range" do
        a = List{1, 3, 4}

        expect_raises IndexError do
          a.insert(4, 1)
        end
      end
    end

    describe "inspect" do
      it { List{1, 2, 3}.inspect.should eq("List{1, 2, 3}") }
    end

    describe "last" do
      it "gets last when non empty" do
        a = List{1, 2, 3}
        a.last.should eq(3)
      end

      it "raises when empty" do
        expect_raises List::NoSuchElementError do
          List(Int32).new.last
        end
      end
    end

    describe "size" do
      it "has size 0" do
        List(Int32).new.size.should eq(0)
      end

      it "has size 2" do
        List{1, 2}.size.should eq(2)
      end
    end

    describe "pop" do
      it "pops when non empty" do
        a = List{1, 2, 3}
        a.pop.should eq(3)
        a.should eq(List{1, 2})
      end

      it "raises when empty" do
        expect_raises List::NoSuchElementError do
          List(Int32).new.pop
        end
      end

      it "pops many elements" do
        a = List{1, 2, 3, 4, 5}
        a.pop(3)
        a.should eq(List{1, 2})
      end

      it "pops more elements than what is available" do
        a = List{1, 2, 3, 4, 5}
        a.pop(10)
        a.should eq(List(Int32).new)
      end

      it "pops negative count raises" do
        a = List{1, 2}
        expect_raises ArgumentError do
          a.pop(-1)
        end
      end
    end

    describe "push" do
      it "adds one element to the list" do
        a = List{"a", "b"}
        a.push("c")
        a.should eq List{"a", "b", "c"}
      end

      it "returns a node" do
        a = List{1, 2}
        a.push(3).should be_a(List::Node(Int32))
      end

      describe "<< alias" do
        it "adds one element to the list" do
          a = List{"a", "b"}
          a << "c"
          a.should eq List{"a", "b", "c"}
        end

        it "returns the list" do
          a = List{1, 2}
          (a << 3).should eq List{1, 2, 3}
        end
      end
    end

    describe "rotate!" do
      it "rotates" do
        a = List{1, 2, 3, 4, 5}
        a.rotate!
        a.should eq(List{2, 3, 4, 5, 1})
        a.rotate!(-2)
        a.should eq(List{5, 1, 2, 3, 4})
        a.rotate!(10)
        a.should eq(List{5, 1, 2, 3, 4})
      end

      it "rotates with size=capacity" do
        a = List{1, 2, 3, 4}
        a.rotate!
        a.should eq(List{2, 3, 4, 1})
        a.rotate!(-2)
        a.should eq(List{4, 1, 2, 3})
        a.rotate!(8)
        a.should eq(List{4, 1, 2, 3})
      end
    end

    describe "shift" do
      it "shifts when non empty" do
        a = List{1, 2, 3}
        a.shift.should eq(1)
        a.should eq(List{2, 3})
      end

      it "raises when empty" do
        expect_raises List::NoSuchElementError do
          List(Int32).new.shift
        end
      end

      it "shifts many elements" do
        a = List{1, 2, 3, 4, 5}
        a.shift(3)
        a.should eq(List{4, 5})
      end

      it "shifts more than what is available" do
        a = List{1, 2, 3, 4, 5}
        a.shift(10)
        a.should eq(List(Int32).new)
      end

      it "shifts negative count raises" do
        a = List{1, 2}
        expect_raises ArgumentError do
          a.shift(-1)
        end
      end
    end

    describe "swap" do
      it "swaps" do
        a = List{1, 2, 3}
        a.swap(0, 2)
        a.should eq(List{3, 2, 1})
      end

      it "swaps with negative indices" do
        a = List{1, 2, 3}
        a.swap(-3, -1)
        a.should eq(List{3, 2, 1})
      end

      it "swaps but raises out of bounds on left" do
        a = List{1, 2, 3}
        expect_raises IndexError do
          a.swap(3, 0)
        end
      end

      it "swaps but raises out of bounds on right" do
        a = List{1, 2, 3}
        expect_raises IndexError do
          a.swap(0, 3)
        end
      end
    end

    describe "to_s" do
      it "does to_s" do
        List{1, 2, 3}.to_s.should eq("List{1, 2, 3}")
      end

      it "does with recursive" do
        deq = List(RecursiveList).new
        deq << deq
        deq.to_s.should eq("List{List{...}}")
      end
    end

    describe "unshift" do
      it "appends at the beginning" do
        a = List{2, 3}
        expected = List{1, 2, 3}
        a.unshift(1)
        a.should eq(expected)
      end

      it "returns a node" do
        a = List{2, 3}
        a.unshift(1).should be_a(List::Node(Int32))
      end
    end

    describe "each iterator" do
      it "does next" do
        a = List{1, 2, 3}
        iter = a.each
        iter.next.should eq(1)
        iter.next.should eq(2)
        iter.next.should eq(3)
        iter.next.should be_a(Iterator::Stop)

        iter.rewind
        iter.next.should eq(1)
      end

      it "cycles" do
        List{1, 2, 3}.cycle.first(8).join.should eq("12312312")
      end

      # TODO ?
      # it "works while modifying deque" do
      #   a = List{1, 2, 3}
      #   count = 0
      #   it = a.each
      #   it.each do
      #     count += 1
      #     a.clear
      #   end
      #   count.should eq(1)
      # end

      describe "cycle" do
        it "cycles" do
          a = [] of Int32
          List{1, 2, 3}.cycle do |x|
            a << x
            break if a.size == 9
          end
          a.should eq([1, 2, 3, 1, 2, 3, 1, 2, 3])
        end

        it "cycles N times" do
          a = [] of Int32
          List{1, 2, 3}.cycle(2) do |x|
            a << x
          end
          a.should eq([1, 2, 3, 1, 2, 3])
        end

        it "cycles with iterator" do
          List{1, 2, 3}.cycle.first(5).to_a.should eq([1, 2, 3, 1, 2])
        end

        it "cycles with N and iterator" do
          List{1, 2, 3}.cycle(2).to_a.should eq([1, 2, 3, 1, 2, 3])
        end
      end
    end
  end
end
