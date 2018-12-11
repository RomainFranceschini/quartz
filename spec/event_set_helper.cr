class MySchedulable
  include Schedulable
  getter int : Int32
  def_equals @int

  def ==(other : Int32)
    @int == other
  end

  def initialize(@int : Int32)
  end
end

struct Int32
  def ==(other : MySchedulable)
    self == other.int
  end
end
