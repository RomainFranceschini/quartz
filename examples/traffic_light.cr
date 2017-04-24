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
    when :red    then 60
    when :green  then 50
    when :orange then 10
    else              Quartz::INFINITY
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
    @phase == :idle ? 200 : 100
  end
end

class PortObserver
  include Quartz::ObserverWithInfo

  def initialize(port : Quartz::OutputPort)
    port.add_observer(self)
  end

  def update(observable, info)
    if observable.is_a?(Quartz::OutputPort) && info
      payload = info[:payload]
      puts "#{observable.host}@#{observable} sends '#{payload}' at #{observable.host.as(Quartz::AtomicModel).time}"
    end
  end
end

coupled = Quartz::CoupledModel.new(:crossroad)
coupled << TrafficLight.new(:traffic_light)
coupled << Policeman.new(:policeman)
coupled.attach :traffic_light, to: :interrupt, between: :policeman, and: :traffic_light
PortObserver.new(coupled[:traffic_light].output_port(:observed))

simulation = Quartz::Simulation.new(coupled, duration: 1000)
simulation.simulate
