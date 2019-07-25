require "../src/quartz"

class HeatCell < Quartz::MultiComponent::Component
  T_AMBIENT  =  27.0f32
  T_IGNITE   = 300.0f32
  T_GENERATE = 500.0f32
  T_BURNED   =  60.0f32
  TIMESTEP   =        1
  RADIUS     =        3
  TMP_DIFF   = T_AMBIENT

  state_var temperature : Float32 = T_AMBIENT
  state_var ignite_time : Float64 = Float64::INFINITY
  state_var phase : Symbol = :inactive
  state_var old_temp : Float32 = T_AMBIENT
  state_var surrounding_temps : Hash(Quartz::Name, Float32) = Hash(Quartz::Name, Float32).new(default_value: T_AMBIENT.to_f32)
  state_var time : Float64 = 0.0

  getter x : Int32 = 0
  getter y : Int32 = 0

  def initialize(name, state, @x, @y)
    super(name, state)
  end

  def initialize(name, @x, @y)
    super(name)
  end

  def new_phase
    if @temperature > T_IGNITE || (@temperature > T_BURNED && @phase == :burning)
      :burning
    elsif @temperature < T_BURNED && @phase == :burning
      :burned
    else
      :unburned
    end
  end

  def time_advance : Quartz::Duration
    case @phase
    when :inactive, :burned
      Quartz::Duration::INFINITY
    else # when :unburned, :burning
      Quartz.duration(1)
    end
  end

  def internal_transition : Hash(Quartz::Name, Quartz::Any)
    proposed_states = Hash(Quartz::Name, Quartz::Any).new

    new_old_temp = @old_temp
    sum = influencers.map { |i| @surrounding_temps[i.name] }.reduce { |acc, i| acc + i }

    if (@temperature - @old_temp).abs > TMP_DIFF
      influencees.each do |j|
        next if j == self
        proposed_states[j.name] = Quartz::Any.new(@temperature)
      end
      new_old_temp = @temperature
    end

    ct = @time + self.time_advance.to_f

    new_temp = case @phase
               when :burning
                 0.98689 * @temperature + 0.0031 * sum + 2.74 * Math.exp(-0.19 * (ct * TIMESTEP - @ignite_time)) + 0.213
               when :unburned
                 0.98689 * @temperature + 0.0031 * sum + 0.213
               else
                 @temperature
               end

    n_phase = self.new_phase
    new_ignite_time = ct * TIMESTEP if @phase == :unburned && n_phase == :burning

    nstate = HeatCell::State.new(
      old_temp: new_old_temp,
      temperature: new_temp.to_f32,
      phase: n_phase,
      ignite_time: new_ignite_time || @ignite_time,
      surrounding_temps: @surrounding_temps,
      time: time
    )

    proposed_states[self.name] = Quartz::Any.new(nstate)
    proposed_states
  end

  def reaction_transition(states)
    temps = @surrounding_temps

    influence = false
    states.each_with_index do |tuple, i|
      influencer, val = tuple
      case influencer
      when self.name
        self.state = val.raw.as(HeatCell::State)
      else
        influence = true
        temps[influencer] = val.as_f32
      end
    end

    @surrounding_temps = temps
    if influence && @phase == :inactive
      @phase = :unburned
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
                 state = HeatCell::State.new(temperature: value.to_f32, ignite_time: 0, phase: phase)
                 HeatCell.new(name, state, x, y)
               else
                 HeatCell.new(name, x, y)
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

  def update(model, info)
    if model.is_a?(HeatMultiPDEVS)
      model = model.as(HeatMultiPDEVS)
      puts CLR

      i = 0
      while i < @rows
        j = 0
        while j < @columns
          case model.cells[i][j].phase
          when :inactive, :unburned
            print "❀ "
          when :burning
            print "◼ "
          when :burned
            print "  "
          end
          j += 1
        end
        print "\n"
        i += 1
      end
      print "\n\nt=#{info[:time]}\n"
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
  simulation = Quartz::Simulation.new(model, duration: Quartz::Duration.new(600))
  c = Consolify.new(model, simulation) if CLI
  simulation.simulate
else
  STDERR.puts "You should provide initial grid file"
  exit 1
end
