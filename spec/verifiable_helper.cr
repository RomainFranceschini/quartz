require "big"

class MyModel
  include Quartz::Stateful
  include Quartz::Verifiable

  state do
    var buffer : Array(Int32)? = nil
    var number : Float32 = Float32::NAN
    var bool : Bool = false
    var string : String = ""
  end

  def initialize(state)
    self.state = state
  end

  def initialize
  end
end

class NumericModel
  include Quartz::Stateful
  include Quartz::Verifiable

  state do
    var int : Int32 = 0i32
    var float : Float64 = 0.0f64
    var rational : BigRational = BigRational.new(0, 1)
    var bigint : BigInt = BigInt.new(0)
    var bigfloat : BigFloat = BigFloat.new(0.0)
    var nilint : Int32? = nil
  end

  def initialize(state)
    self.state = state
  end

  def initialize
  end
end

class SmallModel
  include Quartz::Stateful
  include Quartz::Verifiable

  state do
    var weight : Float64 = 0.0 # in kg
    var height : Int32 = 0     # in cm
  end

  def initialize
  end

  def initialize(state)
    self.state = state
  end
end
