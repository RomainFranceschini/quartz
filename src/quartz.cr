module Quartz

  alias Name = String | Symbol

  # TODO Use Generics when fixed
  alias AnyNumber = Int8 |
                    Int16 |
                    Int32 |
                    Int64 |
                    UInt8 |
                    UInt16 |
                    UInt32 |
                    UInt64 |
                    Float32 |
                    Float64

  # TODO Use Generics when fixed
  alias Type = Nil |
               Bool |
               AnyNumber |
               String |
               Symbol |
               Array(Type) |
               Slice(Type) |
               Hash(Type, Type) |
               Coupleable |
               Quartz::MultiComponent::ComponentState |
               Quartz::MAS::Influence |
               Quartz::MAS::Sensor

  alias SimulationTime = AnyNumber

  INFINITY = Float64::INFINITY

  # Returns the current version
  def self.version
    VERSION
  end
end

require "./quartz/version"
require "./quartz/comparison"
require "./quartz/any"
require "./quartz/list"
require "./quartz/logging"
require "./quartz/errors"
require "./quartz/observer"
require "./quartz/hooks"
require "./quartz/port"
require "./quartz/coupleable"
require "./quartz/coupler"
require "./quartz/transitions"
require "./quartz/schedulers"
require "./quartz/model"
require "./quartz/atomic_model"
require "./quartz/coupled_model"
require "./quartz/simulable"
require "./quartz/processor"
require "./quartz/simulator"
require "./quartz/coordinator"
require "./quartz/pdevs"
#require "./quartz/cdevs"
require "./quartz/dsde"
require "./quartz/multi_component"
require "./quartz/processor_factory"
require "./quartz/simulation"

require "../examples/mas/src/mas"
