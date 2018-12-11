require "../src/quartz"

class Ev
  include Quartz::Schedulable
  getter :num

  def initialize(@num : Int32)
  end
end

prng = ARGV.size == 1 ? Random.new(ARGV.first.to_i64) : Random.new
steps = 100_000
n = 500_000

# file = File.new("pes_pdevs.dat", "wb")
file = File.new("pes_pdevs_time_events.dat", "w")

MAX_RESCHEDULES = 100
MAX_TIME_NEXT   = Quartz::Duration::MULTIPLIER_MAX.to_i64

t0 = Time.monotonic
priority_queue = :fibonacci_heap
pes = Quartz::EventSet(Ev).new(priority_queue)
imm = Set(Ev).new
is_ladder = priority_queue == :ladder_queue

events = [] of Tuple(Quartz::Duration, Ev)
n.times do |i|
  ev = Ev.new(i)
  duration = Quartz::Duration.new(prng.rand(0i64..MAX_TIME_NEXT))
  events << {duration, ev}
  pes.plan_event(ev, duration)
end
t1 = Time.monotonic
puts "init time: #{t1 - t0} seconds."

steps.times do
  prio = pes.imminent_duration
  pes.advance by: prio
  imm.clear
  imm.concat(pes.pop_imminent_events)

  file.print prio
  file.print ": "
  imm.map(&.num).join(", ", file)
  file.print "\n"

  imm.each do |ev|
    planned_duration = Quartz::Duration.new(prng.rand(prio.multiplier..MAX_TIME_NEXT))

    _, ev = events[ev.num]
    events[ev.num] = {planned_duration, ev}

    unless planned_duration.infinite?
      pes.plan_event(ev, planned_duration)
    end
  end

  reschedules = prng.rand(MAX_RESCHEDULES)
  reschedules.times do
    index = prng.rand(events.size)
    d, ev = events[index]

    unless imm.includes?(ev)
      ev_deleted = true
      if !d.infinite?
        c = pes.cancel_event(ev)

        if is_ladder && c.nil?
          ev_deleted = false
        end
      end

      planned_duration = Quartz::Duration.new(prng.rand(prio.multiplier..MAX_TIME_NEXT))
      events[index] = {planned_duration, ev}

      unless planned_duration.infinite?
        if ev_deleted || (!ev_deleted && !planned_duration.zero?)
          pes.plan_event(ev, planned_duration)
        end
      end
    end
  end
end
t2 = Time.monotonic

file.close
puts "simulation time: #{(t2 - t1)} seconds."
