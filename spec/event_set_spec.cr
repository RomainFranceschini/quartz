require "./spec_helper"

class Ev
  property :time_next
  def initialize(@time_next : Int32)
  end
end

class EvF
  property :time_next
  def initialize(@time_next : Float64)
  end
end

class EventSetTester
  @cq : CalendarQueue(Ev)
  @lq : LadderQueue(Ev)
  @st : SplayTree(Ev)
  @bh : BinaryHeap(Ev)

  def initialize
    @cq = CalendarQueue(Ev).new
    @lq = LadderQueue(Ev).new
    @st = SplayTree(Ev).new
    @bh = BinaryHeap(Ev).new
  end

  def test(&block : (CalendarQueue(Ev)|LadderQueue(Ev)|SplayTree(Ev)|BinaryHeap(Ev)) ->)
    it "(CalendarQueue)" { block.call(@cq) }
    it "(LadderQueue)" { block.call(@lq) }
    it "(SplayTree)" { block.call(@st) }
    it "(BinaryHeap)" { block.call(@bh) }
  end
end

class EventSetTesterF
  @cq : CalendarQueue(EvF)
  @lq : LadderQueue(EvF)
  @st : SplayTree(EvF)
  @bh : BinaryHeap(EvF)

  def initialize
    @cq = CalendarQueue(EvF).new
    @lq = LadderQueue(EvF).new
    @st = SplayTree(EvF).new
    @bh = BinaryHeap(EvF).new
  end

  def test(&block : (CalendarQueue(EvF)|LadderQueue(EvF)|SplayTree(EvF)|BinaryHeap(EvF)) ->)
    it "(CalendarQueue)" { block.call(@cq) }
    it "(LadderQueue)" { block.call(@lq) }
    it "(SplayTree)" { block.call(@st) }
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
      events = { Ev.new(2), Ev.new(12), Ev.new(257) }
      events.each { |e| c.push(e) }

      ev = c.delete(events[1])

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12)
    end

    EventSetTesterF.new.test do |c|
      events = { EvF.new(2.0), EvF.new(12.0), EvF.new(257.0) }
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

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12)

      ev.not_nil!.time_next = 0
      c.push(ev.not_nil!)

      c.peek.time_next.should eq(0)
    end

    EventSetTesterF.new.test do |c|
      events = { EvF.new(2.0), EvF.new(12.0), EvF.new(257.0) }
      events.each { |e| c.push(e) }

      ev = c.delete(events[1])

      ev.should_not be_nil
      ev.not_nil!.time_next.should eq(12.0)

      ev.not_nil!.time_next = 0.0
      c.push(ev.not_nil!)

      c.peek.time_next.should eq(0.0)
    end
  end

  describe "passes pdevs test" do
    n = 20_000
    steps = 2_000
    max_reschedules = 50

    EventSetTester.new.test do |pes|
      events = [] of Ev
      n.times do
        ev = Ev.new(rand(0..n))
        events << ev
        pes << ev
      end

      pes.size.should eq(n)

      steps.times do
        prio = pes.next_priority
        imm = pes.delete_all(prio)

        imm.each do |ev|
          ev.time_next.should eq(prio)
          ev.time_next += rand(0..n)
          pes.push(ev)
        end

        rand(max_reschedules).times do
          ev = events[rand(events.size)]
          c = pes.delete(ev)

          c.should_not be_nil
          ev.should eq(c)
          ev.time_next.should eq(c.not_nil!.time_next)

          ev.time_next += rand(0..n)
          pes.push(ev)
        end
      end
    end

    EventSetTesterF.new.test do |pes|
      events = [] of EvF
      n.times do
        ev = EvF.new(rand(0.0..n.to_f))
        events << ev
        pes << ev
      end

      pes.size.should eq(n)

      steps.times do
        prio = pes.next_priority
        imm = pes.delete_all(prio)

        imm.each do |ev|
          ev.time_next.should eq(prio)
          ev.time_next += rand(0.0..n.to_f)
          pes.push(ev)
        end

        rand(max_reschedules).times do
          ev = events[rand(events.size)]
          c = pes.delete(ev)

          c.should_not be_nil
          ev.should eq(c)
          ev.time_next.should eq(c.not_nil!.time_next)

          ev.time_next += rand(0.0..n.to_f)
          pes.push(ev)
        end
      end
    end
  end

end
