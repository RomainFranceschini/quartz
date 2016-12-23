require "./quartz/version"
require "./quartz/types"
require "./quartz/comparison"
require "./quartz/any"
require "./quartz/list"
require "./quartz/simple_hash"
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
require "./quartz/atomic"
require "./quartz/coupled"
require "./quartz/simulable"
require "./quartz/processor"
require "./quartz/simulator"
require "./quartz/coordinator"
require "./quartz/root"
require "./quartz/dsde"
require "./quartz/multi_component"
require "./quartz/processor_factory"
require "./quartz/simulation"

module Quartz
  # Returns the current version
  def self.version
    VERSION
  end
end
