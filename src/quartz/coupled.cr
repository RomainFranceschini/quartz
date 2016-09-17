module Quartz
  # This class represent a PDEVS coupled model.
  class CoupledModel < Model
    include Coupleable
    include Coupler

    # @@preferred_scheduler : Symbol?
    # def self.preferred_scheduler=(scheduler)
    #   @@preferred_scheduler = scheduler
    # end
    #
    # def self.preferred_scheduler
    #   @@preferred_scheduler
    # end

  end
end
