require "./spec_helper"

private class Ev
  property :time_next
  def initialize(@time_next : Int32)
  end
end

private class EvF
  property :time_next
  def initialize(@time_next : Float64)
  end
end

private class EventSetTester
  @cq : CalendarQueue(Ev) = CalendarQueue(Ev).new
  @lq : LadderQueue(Ev) = LadderQueue(Ev).new
  @bh : BinaryHeap(Ev) = BinaryHeap(Ev).new

  def test(&block : EventSet(Ev) ->)
    it "(CalendarQueue)" { block.call(@cq) }
    it "(LadderQueue)" { block.call(@lq) }
    it "(BinaryHeap)" { block.call(@bh) }
  end
end

private class EventSetTesterF
  @cq : CalendarQueue(EvF) = CalendarQueue(EvF).new
  @lq : LadderQueue(EvF) = LadderQueue(EvF).new
  @bh : BinaryHeap(EvF) = BinaryHeap(EvF).new

  def test(&block : EventSet(EvF) ->)
    it "(CalendarQueue)" { block.call(@cq) }
    it "(LadderQueue)" { block.call(@lq) }
    it "(BinaryHeap)" { block.call(@bh) }
  end
end

describe "Event sets" do
  describe "empty" do
    describe "size should be zero" do
      EventSetTester.new.test do |c|
        c.size.should eq(0)
        c.empty?.should be_true
      end

      EventSetTesterF.new.test do |c|
        c.size.should eq(0)
        c.empty?.should be_true
      end
    end
  end

  describe "does clear" do
    EventSetTester.new.test do |c|
      3.times { |i| c.push(Ev.new(i)) }
      c.clear
      c.size.should eq(0)
    end

    EventSetTesterF.new.test do |c|
      3.times { |i| c.push(EvF.new(i.to_f)) }
      c.clear
      c.size.should eq(0)
    end
  end

  describe "prioritizes elements" do
    EventSetTester.new.test do |c|
      events = { Ev.new(2), Ev.new(12), Ev.new(257) }
      events.each { |e| c.push(e) }

      c.pop.time_next.should eq(2)

      c.push(Ev.new(0))

      c.pop.time_next.should eq(0)
      c.pop.time_next.should eq(12)
      c.pop.time_next.should eq(257)
    end

    EventSetTesterF.new.test do |c|
      events = { EvF.new(2.0), EvF.new(12.0), EvF.new(257.0) }
      events.each { |e| c.push(e) }

      c.pop.time_next.should eq(2.0)

      c.push(EvF.new(0.0))

      c.pop.time_next.should eq(0.0)
      c.pop.time_next.should eq(12.0)
      c.pop.time_next.should eq(257.0)
    end
  end

  describe "peek lowest priority" do
    EventSetTester.new.test do |c|
      n = 30
      (0...n).map { |i| Ev.new(i) }.shuffle.each { |e| c.push(e) }
      c.peek.time_next.should eq(0)
    end

    EventSetTesterF.new.test do |c|
      n = 30
      (0...n).map { |i| EvF.new(i.to_f) }.shuffle.each { |e| c.push(e) }
      c.peek.time_next.should eq(0.0)
    end
  end

  describe "deletes" do
    EventSetTester.new.test do |c|
      # ladder queue is allowed to return nil
      next if c.is_a?(LadderQueue)

      events = {Ev.new(2), Ev.new(12), Ev.new(257)}
      events.each { |e| c.push(e) }

      ev = c.delete(events[1])

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12)
    end

    EventSetTesterF.new.test do |c|
      # ladder queue is allowed to return nil
      next if c.is_a?(LadderQueue)

      events = {EvF.new(2.0), EvF.new(12.0), EvF.new(257.0)}
      events.each { |e| c.push(e) }

      ev = c.delete(events[1])

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12.0)
    end
  end

  describe "adjust" do
    EventSetTester.new.test do |c|
      events = { Ev.new(2), Ev.new(12), Ev.new(257) }
      events.each { |e| c.push(e) }

      ev = c.delete(events[1])

      if c.is_a?(LadderQueue) && ev.nil?
        ev = events[1]
      end

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12)

      ev.not_nil!.time_next = 0
      c.push(ev.not_nil!)

      c.peek.time_next.should eq(0)

      c.pop.time_next.should eq(0)
      c.pop.time_next.should eq(2)
      c.pop.time_next.should eq(257)
    end

    EventSetTesterF.new.test do |c|
      events = { EvF.new(2.0), EvF.new(12.0), EvF.new(257.0) }
      events.each { |e| c.push(e) }

      ev = c.delete(events[1])

      if c.is_a?(LadderQueue) && ev.nil?
        ev = events[1]
      end

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12.0)

      ev.not_nil!.time_next = 0.0
      c.push(ev.not_nil!)

      c.pop.time_next.should eq(0.0)
      c.pop.time_next.should eq(2.0)
      c.pop.time_next.should eq(257.0)
    end
  end

  describe "passes pdevs test" do
    n = 20_000
    steps = 2_000
    max_reschedules = 50
    max_tn = 100

    EventSetTester.new.test do |pes|
      events = [] of Ev
      n.times do
        ev = Ev.new(rand(0..max_tn))
        events << ev
        pes << ev
      end
      is_ladder = pes.is_a?(LadderQueue)

      pes.size.should eq(n)

      prev_ts = -1

      steps.times do
        if is_ladder
          (pes.size < n).should be_false
        else
          pes.size.should eq(n)
        end

        prio = pes.next_priority

        (prio >= prev_ts).should be_true
        prev_ts = prio

        imm = pes.delete_all(prio)

        imm.each do |ev|
          ev.time_next.should eq(prio)
          ev.time_next += rand(0..max_tn)
          pes.push(ev)
        end

        rand(max_reschedules).times do
          ev = events[rand(events.size)]
          c = pes.delete(ev)

          if !is_ladder
            c.should_not be_nil
            ev.should eq(c)
            ev.time_next.should eq(c.not_nil!.time_next)
          end

          ta = rand(0..max_tn)
          ev.time_next += ta
          ev_in_ladder = c == nil
          if !is_ladder || (is_ladder && (!ev_in_ladder || (ev_in_ladder && ta > 0)))
            pes.push(ev)
          end
        end
      end
    end

    EventSetTesterF.new.test do |pes|
      events = [] of EvF
      n.times do
        ev = EvF.new(rand(0.0..max_tn.to_f))
        events << ev
        pes << ev
      end
      is_ladder = pes.is_a?(LadderQueue)

      pes.size.should eq(n)
      prev_ts = -1

      steps.times do
        if is_ladder
          (pes.size < n).should be_false
        else
          pes.size.should eq(n)
        end
        prio = pes.next_priority

        (prio >= prev_ts).should be_true
        prev_ts = prio

        imm = pes.delete_all(prio)

        imm.each do |ev|
          ev.time_next.should eq(prio)
          ev.time_next += rand(0.0..max_tn.to_f)
          pes.push(ev)
        end

        rand(max_reschedules).times do
          ev = events[rand(events.size)]
          c = pes.delete(ev)

          if !is_ladder
            c.should_not be_nil
            ev.should eq(c)
            ev.time_next.should eq(c.not_nil!.time_next)
          end

          ta = rand(0..max_tn)
          ev.time_next += ta
          ev_in_ladder = c == nil
          if !is_ladder || (is_ladder && (!ev_in_ladder || (ev_in_ladder && ta > 0)))
            pes.push(ev)
          end
        end
      end
    end
  end
end
