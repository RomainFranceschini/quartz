class MyCoupleable < Model
  include Coupleable

  def find_create(name, mode : IOMode)
    if mode == IOMode::Input
      find_or_create_input_port_if_necessary(name)
    else
      find_or_create_output_port_if_necessary(name)
    end
  end
end

class MyCoupler < Model
  include Coupleable
  include Coupler
end
