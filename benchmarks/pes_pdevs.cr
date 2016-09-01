require "./src/quartz"

class Ev
  property :time_next
  def initialize(@time_next : Int32)
  end
end

iterations = 1
trials = 100_000
n = 500_000

puts "# size  scheduler  distribution  time"

iterations.times do |iteration|
  t0 = Time.now
  pes = Quartz::CalendarQueue(Ev).new
  #pes = Quartz::LadderQueue(Ev).new
  #pes = Quartz::BinaryHeap(Ev).new
  #pes = Quartz::SplayTree(Ev).new

  events = [] of Ev
  n.times do
    ev = Ev.new(rand(0..n))
    events << ev
    pes << ev
  end
  t1 = Time.now
  puts "init time: #{t1 - t0} seconds."
  #puts pes.inspect
  i = 0
  while i < trials
    imm = pes.delete_all(pes.next_priority)
    j = 0
    while j < imm.size
      ev = imm[j]
      ev.time_next += rand(0..n)
      pes.push(ev)
      j+=1
    end
    j = 0
    while j < rand(50)
      ev = events[rand(events.size)]
      c = pes.delete(ev)

      if c == nil || c != ev
        puts "catastropheu"
      end

      ev.time_next += rand(0..n)
      pes.push(ev)
      j+=1
    end
    i+=1
  end
  t2 = Time.now

  pes = nil
  events = nil
  puts "#{iteration} #{(t2-t1)}"
end
