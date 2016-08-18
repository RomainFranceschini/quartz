require "../src/oscillator"

class HeatCell < DEVS::MultiComponent::Component
  T_AMBIENT = 27.0f32
  T_IGNITE = 300.0f32
  T_GENERATE = 500.0f32
  T_BURNED = 60.0f32
  TIMESTEP = 1
  RADIUS = 3
  TMP_DIFF = T_AMBIENT

  # TODO : make immutable and fix transitions accordingly
  struct HeatState < DEVS::MultiComponent::ComponentState
    property temperature : Float32 = T_AMBIENT
    property ignite_time : DEVS::SimulationTime = DEVS::INFINITY
    property phase : Symbol = :inactive
    property old_temp : Float32 = T_AMBIENT
    property surrounding_temps = Hash(DEVS::Name,Float32).new(default_value: T_AMBIENT.to_f32)

    def initialize(@temperature = T_AMBIENT, @ignite_time = DEVS::INFINITY, @phase = :inactive)
    end
  end

  getter state : HeatState
  property x : Int32 = 0
  property y : Int32 = 0

  def initialize(name, @state : HeatState)
    super(name)
  end

  def initialize(name)
    super(name)
    @state = HeatState.new
  end

  def new_phase
    if @state.temperature > T_IGNITE || (@state.temperature > T_BURNED && @state.phase == :burning)
      :burning
    elsif @state.temperature < T_BURNED && @state.phase == :burning
      :burned
    else
      :unburned
    end
  end

  def time_advance
    case @state.phase
    when :inactive, :burned
      DEVS::INFINITY
    else #when :unburned, :burning
      1
    end
  end

  def internal_transition
    proposed_states = Hash(DEVS::Name, DEVS::Any).new

    nstate = @state.dup

    sum = influencers.map { |i| @state.surrounding_temps[i.name] }.reduce  { |acc, i| acc + i }

    if (@state.temperature - @state.old_temp).abs > TMP_DIFF
      influencees.each do |j|
        next if j == self
        proposed_states[j.name] = DEVS::Any.new(@state.temperature)
      end
      nstate.old_temp = @state.temperature
    end

    ct = @time + self.time_advance

    new_temp = case @state.phase
    when :burning
      0.98689 * @state.temperature + 0.0031 * sum + 2.74 * Math.exp(-0.19 * (ct * TIMESTEP - @state.ignite_time)) + 0.213
    when :unburned
      0.98689 * @state.temperature + 0.0031 * sum + 0.213
    else
      @state.temperature
    end

    n_phase = self.new_phase

    nstate.ignite_time = ct * TIMESTEP if @state.phase == :unburned && n_phase == :burning
    nstate.phase = n_phase
    nstate.temperature = new_temp.to_f32

    proposed_states[self.name] = DEVS::Any.new(nstate)

    proposed_states
  end

  def reaction_transition(states)
    temps = @state.surrounding_temps
    influence = false
    states.each_with_index do |tuple, i|
      influencer, val = tuple
      case influencer
      when self.name
        @state = val.raw.as(HeatState)
      else
        influence = true
        temps[influencer] = val.as_f32
      end
    end
    @state.surrounding_temps = temps
    if influence && @state.phase == :inactive
      @state.phase = :unburned
    end
  end
end

class HeatMultiPDEVS < DEVS::MultiComponent::Model
  getter rows : Int32 = 0
  getter columns : Int32 = 0
  getter cells : Array(Array(HeatCell))

  def initialize(name, filepath)
    super(name)

    @cells = Array(Array(HeatCell)).new
    file = File.new(filepath, "r")
    irow = 0
    file.each_line do |l|
      icol = 0
      row = l.split(/[ ]+/).map(&.to_i).map do |column|
        name = "cell_#{icol}_#{irow}"
        cell = if column > HeatCell::T_AMBIENT
          phase = column >= HeatCell::T_IGNITE ? :burning : :unburned
          state = HeatCell::HeatState.new(temperature: column.to_f32, ignite_time: 0, phase: phase)
          HeatCell.new(name, state)
        else
          HeatCell.new(name)
        end

        self << cell
        icol += 1
        cell
      end
      cells << row
      irow += 1
    end

    puts irow

    @rows = cells.size
    @columns = cells.first.size

    # set neighbors
    moore_order = 1
    row = 0
    while row < rows # height
      col = 0
      while col < columns # width
        cell = cells[col][row]

        cell.x = col
        cell.y = row

        cell.influencees << cell
        cell.influencers << cell

        i = -moore_order + row
        while i < moore_order + row + 1
          j = -moore_order + col
          while j < moore_order + col + 1
            if (i != row || j != col) && i >= 0 && j >= 0 && i < rows && j < columns
              neighbor = cells[j][i]
              cell.influencers << neighbor
              cell.influencees << neighbor
            end
            j+=1
          end
          i+=1
        end
        col+=1
      end
      row+=1
    end

  end
end

# FIXME: observer is broken
# class Consolify
#   include DEVS::TransitionObserver
#
#   CLR = "\033c"
#
#   @rows : Int32
#   @columns : Int32
#   @sim : DEVS::Simulation
#
#   def initialize(model : HeatMultiPDEVS, @sim)
#     @rows = model.rows
#     @columns = model.columns
#     model.add_observer(self)
#   end
#
#   def update(model, kind)
#     model = model.as(HeatMultiPDEVS)
#     puts CLR
#
#     i = 0
#     while i < @rows
#       j = 0
#       while j < @columns
#         case model.cells[i][j].state.phase
#         when :inactive, :unburned
#           print "    ◊ "
#           #print "  "
#         when :burning
#           #print "# "
#           print "%4.0f " % model.cells[i][j].state.temperature
#         when :burned
#           print "  "
#         end
#         j+=1
#       end
#       print "\n"
#       i+=1
#     end
#     print "\n\nt=#{@sim.time}\n"
#     STDOUT.flush
#
#     sleep 0.1
#   end
# end

CLR = "\033c"

if ARGV.size == 1
  filepath = ARGV.first
  model = HeatMultiPDEVS.new(:heat, filepath)
  simulation = DEVS::Simulation.new(model, duration: 1200)

  simulation.each do
    puts CLR

    i = 0
    while i < model.rows
      j = 0
      while j < model.columns
        case model.cells[i][j].state.phase
        when :inactive, :unburned
          print "❀ "
        when :burning
          print "◼ "
        when :burned
          print "  "
        end
        j+=1
      end
      print "\n"
      i+=1
    end
    print "\n\nt=#{simulation.time}\n"
    STDOUT.flush

    sleep 0.03
  end
else
  STDERR.puts "You should provide initial grid file"
  exit 1
end
