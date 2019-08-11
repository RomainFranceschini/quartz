module Quartz
  # This class represent a discrete time base that conforms to `Schedulable`.
  # It it used internally to schedule `DTSS::Simulator`s sharing the same time
  # base in an `EventSet`.
  class TimeBase
    include Schedulable

    getter time_next : Duration
    getter processors : Array(DTSS::Simulator) = Array(DTSS::Simulator).new

    def initialize(@time_next : Duration)
    end
  end
end
