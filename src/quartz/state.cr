module Quartz
  # A base struct that wraps the state of a model. Automatically extended by
  # models through use of the `state` macro.
  abstract class State
    include Transferable

    private STATE_INITIALIZE = [] of _

    macro inherited
      STATE_INITIALIZE = [] of _
    end

    def to_named_tuple
      {% begin %}
        NamedTuple.new(
          {% for ivar in @type.instance_vars %}
            {{ ivar.id }}: @{{ ivar.id }},
          {% end %}
        )
      {% end %}
    end

    def to_hash
      {% begin %}
        {
          {% for ivar in @type.instance_vars %}
            :{{ ivar.id }} => @{{ ivar.id }},
          {% end %}
        }
      {% end %}
    end

    def_clone

    def ==(other : self)
      {% for ivar in @type.instance_vars %}
        return false unless @{{ivar.id}} == other.{{ivar.id}}
      {% end %}
      true
    end

    def ==(other)
      false
    end

    def hash(hasher)
      {% for ivar in @type.instance_vars %}
        hasher = @{{ivar.id}}.hash(hasher)
      {% end %}
      hasher
    end

    def inspect(io)
      io << "<" << self.class.name << ": "
      {% for ivar in @type.instance_vars %}
        io << {{ivar.id.stringify}} << '='
        io << @{{ivar.id}}.inspect(io)
        {% if ivar.id != @type.instance_vars.last.id %}
          io << ", "
        {% end %}
      {% end %}
      io << ">"
    end
  end

  module Stateful
    macro included
      macro inherited
        \{% if @type.superclass.has_constant?("State") %}
          class State < \{{@type.superclass}}::State
          end
        \{% end %}

        macro finished
          \\{% if !@type.has_constant?("STATE_DEFINED") %}
            state()
          \\{% end %}
        end
      end

      class State < Quartz::State
      end

      macro finished
        \{% if !@type.has_constant?("STATE_DEFINED") %}
          state()
        \{% end %}
      end
    end

    # The `state` macro defines a `State` subclass for the current `Model` with
    # the given state variables.
    #
    # The state variables can be given as type declarations or assignments.
    #
    # A block can be passed to this macro, that will be inserted inside the
    # definition of the initialize method.
    #
    # This allows to automatically define state retrieval methods,
    # state serialization/deserialization methods and state initialization
    # methods which will be used for simulation distribution purposes, for
    # constructing model hierarchies from a file, or to allow changing initial
    # state for model parameter exploration.
    #
    # ### Usage
    #
    # Default values can be passed using the type declaration notation:
    #
    # ```
    # class MyModel < AtomicModel
    #   state x : Int32 = 0, y : Int32 = 0
    # end
    # ```
    #
    # Through simple assignments:
    #
    # class MyModel < AtomicModel
    #   state x = 0, y = 0
    # end
    #
    # Or by providing an initialization block:
    #
    # ```
    # class MyModel < AtomicModel
    #   state x : Int32, y : Int32, z : Int32 do
    #     @x = 0
    #     @y = 0
    #     @z = (rand * 100 + 1).to_i32
    #   end
    # end
    # ```
    macro state(*properties, &block)
      private STATE_DEFINED = true

      {% prop_ids = properties.map do |prop|
           if prop.is_a?(Assign)
             prop.target.id
           elsif prop.is_a?(TypeDeclaration)
             prop.var.id
           else
             prop.id
           end
         end %}

      class State
        {% @type.constant("State").constant("STATE_INITIALIZE") << block.body if block.is_a? Block %}

        def initialize(**kwargs)
          {% if @type.constant("State").superclass < Quartz::State %}
            super(**kwargs)
          {% end %}

          {% for block in @type.constant("State").constant("STATE_INITIALIZE") %}
            {{block}}
          {% end %}

          {% for ivar in prop_ids %}
            if val = kwargs[:{{ ivar }}]?
              @{{ ivar }} = val
            end
          {% end %}
        end

        {% for property in properties %}
          getter {{property.id}}

          {% if property.is_a?(Assign) %}
            def {{property.target.id}}=(@{{property.target.id}})
            end
          {% elsif property.is_a?(TypeDeclaration) %}
            def {{property.var.id}}=(@{{property.var.id}} : {{property.type}})
            end
          {% else %}
            def {{property.id}}=(@{{property.id}})
            end
          {% end %}
        {% end %}
      end

      {% for property in prop_ids %}
        def {{property.id}}
          state.{{property.id}}
        end
      {% end %}

      {% for property in properties %}
        {% if property.is_a?(Assign) %}
          def {{property.target.id}}=({{property.target.id}})
            state.{{property.target.id}} = {{property.target.id}}
          end
        {% elsif property.is_a?(TypeDeclaration) %}
          def {{property.var.id}}=({{property.var.id}} : {{property.type}})
            state.{{property.var.id}} = {{property.var.id}}
          end
        {% else %}
          def {{property.id}}=({{property.id}})
            state.{{property.id}} = {{property.id}}
          end
        {% end %}
      {% end %}

      @state : Quartz::State = State.new

      def state
        @state.as(State)
      end

      @initial_state : Quartz::State?

      protected def initial_state
       (@initial_state || State.new).as(State)
      end

      def initial_state=(state : State)
        @initial_state = state
      end

      def state=(state : Quartz::State)
        if state.is_a?(State)
          @state = state
        else
          raise ArgumentError.new("")
        end
      end
    end
  end
end
