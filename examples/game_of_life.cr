require "../src/quartz"

class GOLCell < Quartz::MultiComponent::Component
  getter x : Int32 = 0
  getter y : Int32 = 0

  state_var phase : Symbol = :dead
  state_var nalive : Int32 = 0

  def initialize(name, state, @x, @y)
    super(name, state)
  end

  def initialize(name, @x, @y)
    super(name)
  end

  def death?(nalive)
    phase == :alive && (nalive < 2 || nalive > 3)
  end

  def birth?(nalive)
    phase == :dead && nalive == 3
  end

  def time_advance
    alives = @nalive

    if death?(alives) || birth?(alives)
      1
    else
      Quartz::INFINITY
    end
  end

  def internal_transition
    proposed_states = Quartz::SimpleHash(Quartz::Name, Quartz::Any).new
    alive = @nalive

    phase, n = if death?(alive)
                 {:dead, -1}
               elsif birth?(alive)
                 {:alive, 1}
               else
                 {phase, 0}
               end

    if n != 0
      influencees.each do |j|
        next if j == self
        proposed_states.unsafe_assoc(j.name, Quartz::Any.new(n))
      end
    end

    proposed_states.unsafe_assoc(
      self.name,
      Quartz::Any.new(GOLCell::State.new(phase: phase, nalive: alive))
    )
    proposed_states
  end

  def reaction_transition(states)
    diff = 0

    states.each do |tuple|
      influencer, val = tuple
      case influencer
      when self.name
        self.state = val.raw.as(GOLCell::State)
      else
        diff += val.as_i32
      end
    end

    @nalive += diff
  end
end

class GOLMultiPDEVS < Quartz::MultiComponent::Model
  getter rows : Int32 = 0
  getter columns : Int32 = 0
  getter cells : Array(Array(GOLCell))

  def initialize(name, filepath)
    super(name)

    @cells = Array(Array(GOLCell)).new

    file = File.new(filepath, "r")
    y = 0
    file.each_line do |line|
      x = 0
      row = line.split(/[ ]+/).map(&.to_i).map do |val|
        name = "cell_#{x}_#{y}"
        cell = if val == 0
                 GOLCell.new(name, x, y)
               else
                 GOLCell.new(name, GOLCell::State.new(phase: :alive), x, y)
               end
        self << cell
        x += 1
        cell
      end
      cells << row
      y += 1
    end

    @rows = cells.size
    @columns = cells.first.size

    # set neighbors
    cells.each do |row|
      row.each do |cell|
        cell.influencees << cell
        cell.influencers << cell
        nalive = 0

        ((cell.x - 1)..(cell.x + 1)).each do |x|
          ((cell.y - 1)..(cell.y + 1)).each do |y|
            if x >= 0 && y >= 0 && x < columns && y < rows
              if x != cell.x || y != cell.y
                neighbor = cells[y][x]
                if neighbor.phase == :alive
                  nalive += 1
                end
                cell.influencers << neighbor
                cell.influencees << neighbor
              end
            end
          end
        end

        # update initial state
        cell.initial_state = GOLCell::State.new(phase: cell.phase, nalive: nalive)
      end
    end
  end
end

class Consolify
  include Quartz::Observer

  CLR = "\033c"

  @rows : Int32
  @columns : Int32
  @sim : Quartz::Simulation

  def initialize(model : GOLMultiPDEVS, @sim)
    @rows = model.rows
    @columns = model.columns
    model.add_observer(self)
  end

  def update(model)
    if model.is_a?(GOLMultiPDEVS)
      model = model.as(GOLMultiPDEVS)
      puts CLR

      i = 0
      while i < @rows
        j = 0
        while j < @columns
          case model.cells[i][j].phase
          when :alive
            print "◼ "
          when :dead
            print "  "
          end
          j += 1
        end
        print "\n"
        i += 1
      end
      print "\n\nt=#{@sim.time}\n"
      STDOUT.flush

      sleep 0.1
    end
  end
end

if ARGV.size == 1
  filepath = ARGV.first
  model = GOLMultiPDEVS.new(:life, filepath)
  simulation = Quartz::Simulation.new(model)
  c = Consolify.new(model, simulation)
  simulation.simulate
else
  STDERR.puts "You should provide initial grid file"
  exit 1
end

