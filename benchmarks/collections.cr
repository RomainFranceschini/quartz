require "benchmark"

require "../src/oscillator/list"

n = 50_000
n2 = n >> 1

list = DEVS::List(Int32).new
list2 = DEVS::List(Int32).new
node_index = Hash(Int32, DEVS::List::Node(Int32)).new
ary = Array(Int32).new
deque = Deque(Int32).new

Benchmark.bm do |x|
  x.report("list push") { n.times { |i| list.push(i) } }
  x.report("list push (index)") { n.times { |i| node_index[i] = list2.push(i) } }
  x.report("array push") { n.times { |i| ary.push(i) } }
  x.report("deque push") { n.times { |i| deque.push(i) } }
end

numbers = n.times.to_a.shuffle

Benchmark.bm do |x|
  x.report("list delete (search)") { n2.times { |i| list.delete(numbers[i], false) }}

  x.report("list delete (node)") { n2.times { |i| list2.delete(node_index[i]) }}

  x.report("array delete") do
    n2.times do |i|
      if index = ary.index { |j| numbers[i] == j }
        ary.delete_at(index)
      end
    end
  end

  x.report("deque delete") do
    n2.times do |i|
      if index = deque.index { |j| numbers[i] == j }
        deque.delete_at(index)
      end
    end
  end
end

Benchmark.bm do |x|
  x.report("list pop") { n2.times { |i| list.pop }}
  x.report("array pop") { n2.times { |i| ary.pop }}
  x.report("deque pop") { n2.times { |i| deque.pop }}
end
