require "../src/quartz"

class TrafficLight < Quartz::AtomicModel
  input interrupt
  output observed

  state_var phase : Symbol = :red

  def external_transition(bag)
    value = bag[input_port(:interrupt)].first.as_sym
    case value
    when :to_manual
      @phase = :manual if {:red, :green, :orange}.includes?(@phase)
    when :to_autonomous
      @phase = :red if @phase == :manual
    end
  end

  def internal_transition
    @phase = case @phase
             when :red    then :green
             when :green  then :orange
             when :orange then :red
             else              @phase
             end
  end

  def output
    observed = case @phase
               when :red, :orange then :grey
               when :green        then :orange
               end
    post observed, on: :observed
  end

  def time_advance
    case @phase
    when :red    then Quartz.duration(60)
    when :green  then Quartz.duration(50)
    when :orange then Quartz.duration(10)
    else              Quartz::Duration::INFINITY
    end
  end
end

class Policeman < Quartz::AtomicModel
  output traffic_light

  state_var phase : Symbol = :idle

  def internal_transition
    @phase = case @phase
             when :idle then :working
             else            :idle
             end
  end

  def output
    mode = case @phase
           when :idle    then :to_manual
           when :working then :to_autonomous
           end
    post mode, on: :traffic_light
  end

  def time_advance
    @phase == :idle ? Quartz.duration(200) : Quartz.duration(100)
  end

  def external_transition(bag)
  end
end

class PortObserver
  include Quartz::Observer

  def initialize(port : Quartz::OutputPort)
    port.add_observer(self)
  end

  def update(observable, info)
    if observable.is_a?(Quartz::OutputPort) && info
      payload = info[:payload]
      time = info[:time].as(Quartz::TimePoint)
      puts "#{observable.host}@#{observable} sends '#{payload}' at #{time.to_s}"
    end
  end
end

coupled = Quartz::CoupledModel.new(:crossroad)
coupled << TrafficLight.new(:traffic_light)
coupled << Policeman.new(:policeman)
coupled.attach :traffic_light, to: :interrupt, between: :policeman, and: :traffic_light
PortObserver.new(coupled[:traffic_light].output_port(:observed))

simulation = Quartz::Simulation.new(coupled, duration: Quartz.duration(1000), scheduler: :binary_heap)
simulation.simulate
