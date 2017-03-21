class MyCoupleable < Model
  include Coupleable
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
