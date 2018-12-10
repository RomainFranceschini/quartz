require "./spec_helper"

class Ev
  include Schedulable

  getter num : Int32
  property time_point : TimePoint
  getter planned_duration : Duration

  def initialize(@num)
    @time_point = TimePoint.new
    @planned_duration = Duration.new(0)
    @planned_phase = @planned_duration # planned_phase is used internally by the ladder queue
  end

  def initialize(@num, @planned_duration)
    @time_point = TimePoint.new
    @planned_phase = @planned_duration # planned_phase is used internally by the ladder queue
  end

  def planned_duration=(duration : Duration)
    @planned_duration = @planned_phase = duration
  end

  def inspect(io)
    io << "<Ev#"
    @num.inspect(io)
    io << ", "
    @planned_duration.inspect(io)
    io << '>'
  end
end

private struct PriorityQueueTester
  @cq : CalendarQueue(Ev) = CalendarQueue(Ev).new { |a, b| a <=> b }
  @lq : LadderQueue(Ev) = LadderQueue(Ev).new { |a, b| a <=> b }
  @bh : BinaryHeap(Ev) = BinaryHeap(Ev).new { |a, b| a <=> b }
  @fh : FibonacciHeap(Ev) = FibonacciHeap(Ev).new do |a, b|
    # Special case to special decrease key.
    if b == Duration.new(Duration::MULTIPLIER_MAX, Scale.new(-128_i8))
      1
    else
      a <=> b
    end
  end

  def test(&block : PriorityQueue(Ev) ->)
    it "(BinaryHeap)" { block.call(@bh) }
    it "(CalendarQueue)" { block.call(@cq) }
    it "(LadderQueue)" { block.call(@lq) }
    it "(FibonacciHeap)" { block.call(@fh) }
  end
end

describe "Priority queue" do
  describe "empty" do
    describe "size should be zero" do
      PriorityQueueTester.new.test do |pes|
        pes.size.should eq(0)
        pes.empty?.should be_true
      end
    end
  end

  describe "does clear" do
    PriorityQueueTester.new.test do |pes|
      3.times { |i| pes.push(Duration.new(i), Ev.new(i + 1)) }
      pes.clear
      pes.size.should eq(0)
    end
  end

  describe "prioritizes elements" do
    PriorityQueueTester.new.test do |pes|
      events = {Ev.new(1, Duration.new(2)), Ev.new(2, Duration.new(12)), Ev.new(3, Duration.new(257))}
      events.each { |e| pes.push(e.planned_duration, e) }

      pes.next_priority.should eq(Duration.new(2))
      pes.pop.should eq(events[0])

      new_ev = Ev.new(0)
      pes.push(new_ev.planned_duration, new_ev)

      pes.next_priority.should eq(Duration.new(0))
      pes.pop.should eq(new_ev)

      pes.next_priority.should eq(Duration.new(12))
      pes.pop.should eq(events[1])

      pes.next_priority.should eq(Duration.new(257))
      pes.pop.should eq(events[2])
    end
  end

  describe "peek lowest priority" do
    PriorityQueueTester.new.test do |c|
      n = 30
      (0...n).map { |i| Ev.new(i + 1, Duration.new(i)) }.shuffle.each { |e| c.push(e.planned_duration, e) }
      c.peek.num.should eq(1)
    end
  end

  describe "deletes" do
    PriorityQueueTester.new.test do |c|
      events = {Ev.new(1, Duration.new(2)), Ev.new(2, Duration.new(12)), Ev.new(3, Duration.new(257))}
      events.each { |e| c.push(e.planned_duration, e) }

      ev = c.delete(events[1].planned_duration, events[1])

      # ladder queue is allowed to return nil for performance reasons (invalidation strategy)
      next if ev.nil? && c.is_a?(LadderQueue)

      ev.should_not be_nil
      ev.not_nil!.num.should eq(2)
    end
  end

  describe "adjust" do
    PriorityQueueTester.new.test do |c|
      events = {Ev.new(1, Duration.new(2)), Ev.new(2, Duration.new(12)), Ev.new(3, Duration.new(257))}
      events.each { |e| c.push(e.planned_duration, e) }

      ev = c.delete(events[1].planned_duration, events[1])

      if c.is_a?(LadderQueue) && ev.nil?
        ev = events[1]
      end

      ev.should_not be_nil
      ev.not_nil!.num.should eq(2)
      ev.not_nil!.planned_duration.should eq(Duration.new(12))

      ev.not_nil!.planned_duration = Duration.new(0)
      c.push(Duration.new(0), ev.not_nil!)

      c.peek.planned_duration.should eq(Duration.new(0))
      c.peek.num.should eq(2)

      c.pop.num.should eq(2)
      c.pop.num.should eq(1)
      c.pop.num.should eq(3)
    end
  end

  describe "passes up/down model" do
    n = 100_000

    max_tn = Duration::MULTIPLIER_MAX.to_i64
    prng = Random.new

    events = [] of Ev
    n.times do |i|
      events << Ev.new(i, Duration.new(prng.rand(0i64..max_tn)))
    end

    ev_by_durations = events.group_by &.planned_duration
    sorted_durations = events.map(&.planned_duration).uniq!.sort!

    PriorityQueueTester.new.test do |pes|
      # enqueue
      events.each { |ev| pes.push(ev.planned_duration, ev) }

      # dequeue
      sorted_durations.each do |duration|
        pes.next_priority.should eq(duration)

        imm = ev_by_durations[duration]
        imm.size.times do
          imm.should contain(pes.pop)
        end
      end
    end
  end

  describe "passes pdevs model" do
    n = 50_000
    steps = 5_000
    max_reschedules = 50
    max_tn = Duration::MULTIPLIER_MAX.to_i64 / steps
    seed = rand(Int64::MIN..Int64::MAX)
    sequence = Hash(String, Array(Duration)).new { |h, k| h[k] = Array(Duration).new }

    PriorityQueueTester.new.test do |pes|
      prng = Random.new(seed)
      seq_key = pes.class.name

      events = [] of Ev
      n.times do |i|
        ev = Ev.new(i, Duration.new(prng.rand(0i64..max_tn)))
        events << ev
        pes.push(ev.planned_duration, ev)
      end
      is_ladder = pes.is_a?(LadderQueue)

      pes.size.should eq(n)

      prev_duration = Duration.new(0)

      imm = Set(Ev).new

      steps.times do
        if is_ladder
          (pes.size < n).should be_false
        else
          pes.size.should eq(n)
        end

        prio = pes.next_priority
        sequence[seq_key] << prio

        (prio >= prev_duration).should be_true
        prev_duration = prio

        imm.clear
        while !pes.empty? && pes.next_priority == prio
          imm << pes.pop
        end

        imm.each do |ev|
          ev.planned_duration.should eq(prio)
          ev.planned_duration += Duration.new(prng.rand(0i64..max_tn))

          unless ev.planned_duration.infinite?
            pes.push(ev.planned_duration, ev)
          end
        end

        reschedules = prng.rand(max_reschedules)
        reschedules.times do
          ev = events[prng.rand(events.size)]
          unless imm.includes?(ev)
            remaining = (ev.planned_duration - prio)

            ev_deleted = true
            if !ev.planned_duration.infinite? && !remaining.zero?
              c = pes.delete(ev.planned_duration, ev)

              if is_ladder && c.nil?
                ev_deleted = false
              else
                c.should_not be_nil
                ev.should eq(c)
                ev.planned_duration.should eq(c.not_nil!.planned_duration)
              end
            end

            ta = prng.rand(0i64..max_tn)
            ev.planned_duration += Duration.new(ta)

            unless ev.planned_duration.infinite?
              if ev_deleted || (!ev_deleted && !ev.planned_duration.zero?)
                pes.push(ev.planned_duration, ev)
              end
            end
          end
        end
      end
    end

    ref_key = sequence.keys.first
    sequence.each_key do |key|
      next if key == ref_key
      it "event sequence of #{key} should be same as #{ref_key}" do
        sequence[key].should eq(sequence[ref_key])
      end
    end
  end
end
