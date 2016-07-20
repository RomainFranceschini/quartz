module DEVS
  # This class represent a DEVS coupled model.
  class CoupledModel < Model
    include Container
    include Coupleable

    # @@preferred_scheduler : Symbol?
    # def self.preferred_scheduler=(scheduler)
    #   @@preferred_scheduler = scheduler
    # end
    #
    # def self.preferred_scheduler
    #   @@preferred_scheduler
    # end

    # The *Select* function as defined is the classic DEVS formalism.
    # Selects one model among all. By default returns the first. Override
    # if a different behavior is desired.
    #
    # Example:
    # ```
    # def select(imminent_children)
    #   imminent_children.sample
    # end
    # ```
    def select(imminent_children)
      imminent_children.first
    end
  end
end
