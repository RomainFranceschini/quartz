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
end

private struct EventSetTester
  @cq : CalendarQueue(Ev) = CalendarQueue(Ev).new { |a, b| a <=> b }
  @lq : LadderQueue(Ev) = LadderQueue(Ev).new { |a, b| a <=> b }
  @bh : BinaryHeap(Ev) = BinaryHeap(Ev).new { |a, b| a <=> b }

  def test(&block : PriorityQueue(Ev) ->)
    it "(CalendarQueue)" { block.call(@cq) }
    it "(BinaryHeap)" { block.call(@bh) }
    it "(LadderQueue)" { block.call(@lq) }
  end
end

describe "Priority queues" do
  describe "empty" do
    describe "size should be zero" do
      EventSetTester.new.test do |pes|
        pes.size.should eq(0)
        pes.empty?.should be_true
      end
    end
  end

  describe "does clear" do
    EventSetTester.new.test do |pes|
      3.times { |i| pes.push(Duration.new(i), Ev.new(i + 1)) }
      pes.clear
      pes.size.should eq(0)
    end
  end

  describe "prioritizes elements" do
    EventSetTester.new.test do |pes|
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
    EventSetTester.new.test do |c|
      n = 30
      (0...n).map { |i| Ev.new(i + 1, Duration.new(i)) }.shuffle.each { |e| c.push(e.planned_duration, e) }
      c.peek.num.should eq(1)
    end
  end

  describe "deletes" do
    EventSetTester.new.test do |c|
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
    EventSetTester.new.test do |c|
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

  describe "passes pdevs test" do
    n = 20_000
    steps = 2_000
    max_reschedules = 50
    max_tn = 100

    EventSetTester.new.test do |pes|
      rand = Random.new

      events = [] of Ev
      n.times do |i|
        ev = Ev.new(i, Duration.new(rand(0..max_tn)))
        events << ev
        pes.push(ev.planned_duration, ev)
      end
      is_ladder = pes.is_a?(LadderQueue)

      pes.size.should eq(n)

      prev_duration = Duration.new(0)

      steps.times do |i|
        if is_ladder
          (pes.size < n).should be_false
        else
          pes.size.should eq(n)
        end

        prio = pes.next_priority

        (prio >= prev_duration).should be_true
        prev_duration = prio

        imm = [] of Ev
        while !pes.empty? && pes.next_priority == prio
          imm << pes.pop
        end

        imm.each do |ev|
          ev.planned_duration.should eq(prio)
          ev.planned_duration += Duration.new(rand(0..max_tn))
          raise "ohno" if ev.planned_duration.infinite?
          pes.push(ev.planned_duration, ev)
        end

        reschedules = rand(max_reschedules)
        reschedules.times do
          ev = events[rand(events.size)]
          c = pes.delete(ev.planned_duration, ev)

          unless is_ladder && c.nil?
            c.should_not be_nil
            ev.should eq(c)
            ev.planned_duration.should eq(c.not_nil!.planned_duration)
          end

          ta = rand(0..max_tn)
          ev.planned_duration += Duration.new(ta)
          raise "ohno" if ev.planned_duration.infinite?

          ev_in_ladder = c == nil
          if !is_ladder || (is_ladder && (!ev_in_ladder || (ev_in_ladder && ta > 0)))
            pes.push(ev.planned_duration, ev)
          end
        end
      end
    end
  end
end
