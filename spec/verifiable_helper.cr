require "big"

class MyModel
  include Quartz::Stateful
  include Quartz::Verifiable

  state buffer : Array(Int32)? = nil,
    number : Float32 = Float32::NAN,
    bool : Bool = false,
    string : String = ""

  property buffer, number, bool, string

  def initialize(state)
    self.state = state
  end

  def initialize
  end
end

class NumericModel
  include Quartz::Stateful
  include Quartz::Verifiable

  state int : Int32 = 0i32,
    float : Float64 = 0.0f64,
    rational : BigRational = BigRational.new(0, 1),
    bigint : BigInt = BigInt.new(0),
    bigfloat : BigFloat = BigFloat.new(0.0),
    nilint : Int32? = nil

  setter int, float, rational, bigint, bigfloat, nilint

  def initialize(state)
    self.state = state
  end

  def initialize
  end
end

class SmallModel
  include Quartz::Stateful
  include Quartz::Verifiable

  state weight : Float64 = 0.0, # in kg
    height : Int32 = 0          # in cm

  setter weight, height

  def initialize
  end

  def initialize(state)
    self.state = state
  end
end
