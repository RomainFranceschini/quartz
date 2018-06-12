require "./spec_helper"

class Ev
  getter num : Int32
  property time_point : TimePoint
  property planned_duration : Duration

  def initialize(@num)
    @time_point = TimePoint.new
    @planned_duration = Duration.new(0)
  end

  def initialize(@num, @planned_duration)
    @time_point = TimePoint.new
  end
end

private struct EventSetTester
  # @cq : CalendarQueue(Ev) = CalendarQueue(Ev).new
  # @lq : LadderQueue(Ev) = LadderQueue(Ev).new
  @bh : BinaryHeap(Ev) = BinaryHeap(Ev).new { |a, b| a <=> b }

  def test(&block : PriorityQueue(Ev) ->)
    # it "(CalendarQueue)" { block.call(@cq) }
    # it "(LadderQueue)" { block.call(@lq) }
    it "(BinaryHeap)" { block.call(@bh) }
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
      events = { {2, Ev.new(1)}, {12, Ev.new(2)}, {257, Ev.new(3)} }
      events.each { |e| pes.push(Duration.new(e[0]), e[1]) }

      pes.next_priority.should eq(Duration.new(2))
      pes.pop.should eq(events[0][1])

      new_ev = Ev.new(0)
      pes.push(new_ev.planned_duration, new_ev)

      pes.next_priority.should eq(Duration.new(0))
      pes.pop.should eq(new_ev)

      pes.next_priority.should eq(Duration.new(12))
      pes.pop.should eq(events[1][1])

      pes.next_priority.should eq(Duration.new(257))
      pes.pop.should eq(events[2][1])
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
      # ladder queue is allowed to return nil
      # next if c.is_a?(LadderQueue)

      events = {Ev.new(1, Duration.new(2)), Ev.new(2, Duration.new(12)), Ev.new(3, Duration.new(257))}
      events.each { |e| c.push(e.planned_duration, e) }

      ev = c.delete(events[1].planned_duration, events[1])

      ev.should_not be_nil
      ev.not_nil!.num.should eq(2)
    end
  end

  describe "adjust" do
    EventSetTester.new.test do |c|
      events = {Ev.new(1, Duration.new(2)), Ev.new(2, Duration.new(12)), Ev.new(3, Duration.new(257))}
      events.each { |e| c.push(e.planned_duration, e) }

      ev = c.delete(events[1].planned_duration, events[1])

      # if c.is_a?(LadderQueue) && ev.nil?
      #   ev = events[1]
      # end

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
      events = [] of Ev
      n.times do |i|
        ev = Ev.new(i, Duration.new(rand(0..max_tn)))
        events << ev
        pes.push(ev.planned_duration, ev)
      end
      is_ladder = false # pes.is_a?(LadderQueue)

      pes.size.should eq(n)

      prev_duration = Duration.new(0)

      steps.times do
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
          pes.push(ev.planned_duration, ev)
        end

        rand(max_reschedules).times do
          ev = events[rand(events.size)]
          c = pes.delete(ev.planned_duration, ev)

          if !is_ladder
            c.should_not be_nil
            ev.should eq(c)
            ev.planned_duration.should eq(c.not_nil!.planned_duration)
          end

          ta = rand(0..max_tn)
          ev.planned_duration += Duration.new(ta)
          ev_in_ladder = c == nil
          if !is_ladder || (is_ladder && (!ev_in_ladder || (ev_in_ladder && ta > 0)))
            pes.push(ev.planned_duration, ev)
          end
        end
      end
    end
  end
end
