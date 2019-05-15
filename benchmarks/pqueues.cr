require "benchmark"

require "../src/quartz"

class Ev
  include Quartz::Schedulable
  property :time_next

  def initialize(@time_next : Quartz::Duration)
  end
end

random = Random.new
N             = 1_000_000
MAX_TIME_NEXT = Quartz::Duration::MULTIPLIER_MAX // N
N2            = N >> 1

ladq = Quartz::LadderQueue(Ev).new { |a, b| a <=> b }
calq = Quartz::CalendarQueue(Ev).new { |a, b| a <=> b }
bheap = Quartz::BinaryHeap(Ev).new { |a, b| a <=> b }
fheap = Quartz::FibonacciHeap(Ev).new { |a, b| a <=> b }

events = (0...N).map { Ev.new(Quartz::Duration.new(random.rand(0i64..MAX_TIME_NEXT))) }

Benchmark.bm do |x|
  x.report("ladq#push") { N.times { |i| ladq.push(events[i].time_next, events[i]) } }
  x.report("calq#push") { N.times { |i| calq.push(events[i].time_next, events[i]) } }
  x.report("bheap#push") { N.times { |i| bheap.push(events[i].time_next, events[i]) } }
  x.report("fheap#push") { N.times { |i| fheap.push(events[i].time_next, events[i]) } }
end

numbers = N.times.to_a.shuffle

Benchmark.bm do |x|
  x.report("ladq#delete") { N2.times { |i| ladq.delete(events[numbers[i]].time_next, events[numbers[i]]) } }
  x.report("calq#delete") { N2.times { |i| calq.delete(events[numbers[i]].time_next, events[numbers[i]]) } }
  x.report("bheap#delete") { N2.times { |i| bheap.delete(events[numbers[i]].time_next, events[numbers[i]]) } }
  x.report("fheap#delete") { N2.times { |i| fheap.delete(events[numbers[i]].time_next, events[numbers[i]]) } }
end

Benchmark.bm do |x|
  x.report("ladq#pop") { N2.times { |i| ladq.pop } }
  x.report("calq#pop") { N2.times { |i| calq.pop } }
  x.report("bheap#pop") { N2.times { |i| bheap.pop } }
  x.report("fheap#pop") { N2.times { |i| fheap.pop } }
end
