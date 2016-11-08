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

class Foo < MyCoupleable
  input iport1
  output oport1, :oport2, "oport3"
end

class Bar < Foo
  input :iport2
end
