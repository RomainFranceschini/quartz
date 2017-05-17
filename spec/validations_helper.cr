require "big"

class MyModel
  include Quartz::AutoState
  include Quartz::Validations

  state_var buffer : Array(Int32)?
  state_var number : Float32
  state_var bool : Bool
  state_var string : String

  setter buffer, number, bool, string

  state_initialize do
    @buffer = nil
    @number = Float32::NAN
    @bool = false
    @string = ""
  end

  def initialize(state)
    self.state = state
  end

  def initialize
  end
end

class NumericModel
  include Quartz::AutoState
  include Quartz::Validations

  state_var int : Int32
  state_var float : Float64
  state_var rational : BigRational
  state_var bigint : BigInt
  state_var bigfloat : BigFloat
  state_var nilint : Int32?

  setter int, float, rational, bigint, bigfloat, nilint

  state_initialize do
    @int = 0i32
    @float = 0.0f64
    @rational = BigRational.new(0, 1)
    @bigint = BigInt.new(0)
    @bigfloat = BigFloat.new(0.0)
    @nilint = nil
  end

  def initialize(state)
    self.state = state
  end

  def initialize
  end
end

class SmallModel
  include Quartz::AutoState
  include Quartz::Validations

  state_var weight : Float64 = 0.0 # in kg
  state_var height : Int32 = 0     # in cm

  setter weight, height

  def initialize
  end

  def initialize(state)
    self.state = state
  end
end
