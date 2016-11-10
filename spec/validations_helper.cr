require "big"

class MyModel
  include Quartz::Validations

  property buffer : Array(Int32)?
  property number : Float32
  property bool : Bool
  property string : String

  def initialize(@buffer = nil, @number = Float32::NAN, @bool = false, @string = "")
  end
end

class NumericModel
  include Quartz::Validations

  property int : Int32
  property float : Float64
  property rational : BigRational
  property bigint : BigInt
  property bigfloat : BigFloat
  property nilint : Int32?

  def initialize(
                 @int = 0i32,
                 @float = 0.0f64,
                 @rational = BigRational.new(0, 1),
                 @bigint = BigInt.new(0),
                 @bigfloat = BigFloat.new(0.0),
                 @nilint = nil)
  end
end
