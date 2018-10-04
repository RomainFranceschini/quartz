require "../src/quartz"

class Ev
  property :time_next

  def initialize(@time_next : Int32)
  end
end

seed = ARGV.size == 1 ? ARGV.first.to_u32 : Random.new_seed
pp seed

random = Random.new(seed)

iterations = 1
trials = 100_000
n = 500_000

MAX_RESCHEDULE =     100
MAX_TIME_NEXT  = 500_000

puts "# size  scheduler  distribution  time"

iterations.times do |iteration|
  t0 = Time.monotonic
  # pes = Quartz::CalendarQueue(Ev).new
  pes = Quartz::LadderQueue(Ev).new
  # pes = Quartz::BinaryHeap(Ev).new
  # pes = Quartz::SplayTree(Ev).new

  events = [] of Ev
  n.times do
    ev = Ev.new(random.rand(0..MAX_TIME_NEXT))
    events << ev
    pes << ev
  end
  t1 = Time.monotonic
  puts "init time: #{t1 - t0} seconds."
  # puts pes.inspect
  i = 0
  prev_ts = -1
  while i < trials
    raise "unscheduled events" if pes.size < events.size

    ts = pes.next_priority
    imm = pes.delete_all(ts)

    unless ts >= prev_ts
      puts pes.inspect
      raise "#{ts} >= #{prev_ts}"
    end
    prev_ts = ts

    j = 0
    while j < imm.size
      ev = imm[j]
      unless ev.time_next == ts
        raise "#{ev.time_next} != #{ts}"
      end

      ta = random.rand(0..MAX_TIME_NEXT)

      ev.time_next += ta
      pes.push(ev)
      j += 1
    end

    j = 0
    while j < random.rand(MAX_RESCHEDULE)
      ev = events[random.rand(events.size)]
      c = pes.delete(ev)

      if ev.time_next < ts
        puts "event #{ev} (#{ev.time_next}) was not scheduled"
      end

      ta = random.rand(0..MAX_TIME_NEXT)
      ev.time_next += ta

      is_ladder = pes.is_a?(Quartz::LadderQueue)
      ev_in_ladder = c == nil

      if !is_ladder || (is_ladder && (!ev_in_ladder || (ev_in_ladder && ta > 0)))
        pes.push(ev)
      end

      j += 1
    end
    i += 1
  end
  t2 = Time.monotonic

  pes = nil
  events = nil
  puts "#{iteration} #{(t2 - t1)}"
end
