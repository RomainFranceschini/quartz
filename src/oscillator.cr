require "./oscillator/version"
require "./oscillator/any"
require "./oscillator/logging"
require "./oscillator/errors"
require "./oscillator/observer"
require "./oscillator/hooks"
require "./oscillator/port"
require "./oscillator/coupleable"
require "./oscillator/container"
require "./oscillator/behavior"
require "./oscillator/model"
require "./oscillator/atomic_model"
require "./oscillator/coupled_model"
require "./oscillator/simulable"
require "./oscillator/processor"
require "./oscillator/simulator"
require "./oscillator/coordinator"
require "./oscillator/pdevs"
#require "./oscillator/cdevs"
require "./oscillator/dsde"
require "./oscillator/schedulers"
require "./oscillator/simulation"
#require "./oscillator/builders"

# TODO Validations, Serialization, State?, CDEVS, Extensions, Sim init values, Logging, DEVS::Type solution!!!

module DEVS
  extend self

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

  alias Type = Nil |
               Bool |
               AnyNumber |
               String |
               Symbol |
               Array(Type) |
               Slice(Type) |
               Hash(Type, Type) |
               Coupleable

  alias SimulationTime = AnyNumber

  INFINITY = Float64::INFINITY

  macro print_debug(str)
    {% if env("DEBUG") %}
      puts str
    {% end %}
  end

  # Returns the current version of the gem
  #
  # @return [String] the string representation of the version
  def version
    VERSION
  end
end
