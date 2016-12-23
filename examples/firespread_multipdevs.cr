require "../src/quartz"

class HeatCell < Quartz::MultiComponent::Component
  T_AMBIENT = 27.0f32
  T_IGNITE = 300.0f32
  T_GENERATE = 500.0f32
  T_BURNED = 60.0f32
  TIMESTEP = 1
  RADIUS = 3
  TMP_DIFF = T_AMBIENT

  # TODO : make immutable and fix transitions accordingly
  struct HeatState < Quartz::MultiComponent::ComponentState
    include Quartz::Transferable

    property temperature : Float32 = T_AMBIENT
    property ignite_time : Quartz::SimulationTime = Quartz::INFINITY
    property phase : Symbol = :inactive
    property old_temp : Float32 = T_AMBIENT
    property surrounding_temps = Hash(Quartz::Name,Float32).new(default_value: T_AMBIENT.to_f32)

    def initialize(@temperature = T_AMBIENT, @ignite_time = Quartz::INFINITY, @phase = :inactive)
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
      Quartz::INFINITY
    else #when :unburned, :burning
      1
    end
  end

  def internal_transition
    proposed_states = Quartz::SimpleHash(Quartz::Name, Quartz::Any).new

    nstate = @state.dup

    sum = influencers.map { |i| @state.surrounding_temps[i.name] }.reduce  { |acc, i| acc + i }

    if (@state.temperature - @state.old_temp).abs > TMP_DIFF
      influencees.each do |j|
        next if j == self
        proposed_states.unsafe_assoc(j.name, Quartz::Any.new(@state.temperature))
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

    proposed_states.unsafe_assoc(self.name, Quartz::Any.new(nstate))
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

class HeatMultiPDEVS < Quartz::MultiComponent::Model
  getter rows : Int32 = 0
  getter columns : Int32 = 0
  getter cells : Array(Array(HeatCell))

  def initialize(name, filepath)
    super(name)

    @cells = Array(Array(HeatCell)).new
    file = File.new(filepath, "r")
    y = 0
    file.each_line do |l|
      x = 0
      row = l.split(/[ ]+/).map(&.to_i).map do |value|
        name = "cell_#{x}_#{y}"
        cell = if value > HeatCell::T_AMBIENT
          phase = value >= HeatCell::T_IGNITE ? :burning : :unburned
          state = HeatCell::HeatState.new(temperature: value.to_f32, ignite_time: 0, phase: phase)
          HeatCell.new(name, state)
        else
          HeatCell.new(name)
        end
        cell.x = x
        cell.y = y
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

        ((cell.x - 1)..(cell.x + 1)).each do |x|
          ((cell.y - 1)..(cell.y + 1)).each do |y|
            if x >= 0 && y >= 0 && x < columns && y < rows
              if x != cell.x || y != cell.y
                neighbor = cells[y][x]
                cell.influencers << neighbor
                cell.influencees << neighbor
              end
            end
          end
        end
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

  def initialize(model : HeatMultiPDEVS, @sim)
    @rows = model.rows
    @columns = model.columns
    model.add_observer(self)
  end

  def update(model)
    if model.is_a?(HeatMultiPDEVS)
      model = model.as(HeatMultiPDEVS)
      puts CLR

      i = 0
      while i < @rows
        j = 0
        while j < @columns
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
      print "\n\nt=#{@sim.time}\n"
      STDOUT.flush

      sleep 0.01
    end
  end
end

CLR = "\033c"
CLI = true

if ARGV.size == 1
  filepath = ARGV.first
  model = HeatMultiPDEVS.new(:heat, filepath)
  simulation = Quartz::Simulation.new(model, duration: 600)
  c = Consolify.new(model, simulation) if CLI
  simulation.simulate
else
  STDERR.puts "You should provide initial grid file"
  exit 1
end
