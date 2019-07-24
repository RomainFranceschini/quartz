module Quartz
  # A base struct that wraps the state of a model. Automatically extended by
  # models through use of the `state_var` macro.
  abstract struct State
    include Transferable

    def initialize
    end

    def initialize(pull : JSON::PullParser)
    end

    def to_tuple
      Tuple.new
    end

    def to_named_tuple
      NamedTuple.new
    end

    def to_json(json : JSON::Builder)
    end

    def self.from_json(io : IO)
      self.new(::JSON::PullParser.new(io))
    end

    def self.from_json(str : String)
      from_json(IO::Memory.new(str))
    end
  end

  module AutoState
    macro included
      {% if !@type.constant :STATE_VARIABLES %}
        private STATE_VARIABLES = [] of Nil
        private STATE_INITIALIZE = [] of Nil
      {% end %}

      # The `state_var` macro defines a state variable of a model. Its primary
      # usage is to identify which instance variables are part of the state of
      # the model.
      #
      # This allows to automatically define state retrieval methods,
      # state serialization/deserialization methods and state initialization
      # methods which will be used for simulation distribution purposes, for
      # constructing model hierarchies from a file, or to allow changing initial
      # state for model parameter exploration.
      #
      # ### Usage
      #
      # `state_var` must receive a type declaration which will be used to
      # declare instance variables :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var x : Int32
      #   state_var y : Int32
      # end
      # ```
      #
      # Default values can be passed using the type declaration notation or
      # through a block :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var x : Int32 = 0
      #   state_var y : Int32 = 0
      #   state_var z : Int32 { (rand * 100 + 1).to_i32 }
      #   state_var ß : Int32 { x * 42 }
      # end
      # ```
      #
      # Note from previous example that the initialization block of ß is
      # allowed to reference the value of another state variable.
      #
      # If default values are omitted, a chance is given to initialize those
      # state variables through the `state_initialize` macro :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var x : Int32
      #   state_var y : Int32
      #
      #   state_initialize do
      #     @x = 0
      #     @y = 0
      #   end
      # end
      # ```
      #
      # Multiple calls to `state_var` for the same variable is allowed. Previous
      # properties are inherited and overlapping propertings are overwritten.
      # The following example :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var sigma : Duration = Duration::INFINITY
      #   state_var sigma { Duration.infinity(self.class.precision) }
      # end
      # ```
      #
      # Defines the *sigma* state variable as a `Duration` type with a default
      # value determined by the initialization block.
      #
      # This is particularly useful in case a model inherits another model :
      #
      # ```
      # class BaseModel < AtomicModel
      #   state_var sigma : Duration = Duration::INFINITY
      # end
      #
      # class MyModel < BaseModel
      #   state_var sigma = Quartz.duration(85, milli)
      # end
      # ```
      #
      #
      # All `initialize` methods defined in the included type and its subclasses
      # will be redefined to include the body of the given block.
      # Note that the block content is always included at the top of the method
      # definition. Thus, if you define :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var x : Int32
      #   state_var y : Int32
      #
      #   state_initialize do
      #     @x = 0
      #     @y = 0
      #   end
      #
      #   def initialize(name)
      #     super(name)
      #     add_input_port("in")
      #   end
      # end
      # ```
      #
      # The constructor will be automatically redefined to :
      #
      # ```
      #   def initialize(name)
      #     @x = 0
      #     @y = 0
      #     super(name)
      #     add_input_port("in")
      #   end
      # end
      # ```
      #
      # #### Options
      #
      # Along with the type declaration, `state_var` also accept a hash or
      # named tuple literal whose keys corresponds to the following options :
      # * **visibility**: used to restrict the visibility of the getter that
      # is defined for this state variable (`:private` or `:protected`). No
      # restriction is applied by default (public) :
      # ```
      # state_var hidden : Bool = true, visibility: :private
      # ```
      # * **converter**: specify an alternate type for parsing and generation.
      # Examples of converters are `Time::Format` and `Time::EpochConverter`
      # for `Time`.
      # ```
      # state_var timestamp : Time, converter: Time::EpochConverter
      # ```
      #
      # #### Code generation
      #
      # A getter is generated for each declared state variable, whose visibility
      # can be restricted through the **visibility** option.
      #
      # When the type definition is complete, a struct wrapping all state
      # variables is defined for convenience.
      macro state_var(prop, **nopts, &block)
        \{% index = STATE_VARIABLES.size %}
        \{% opts = nopts %}
        \{% for var, i in STATE_VARIABLES %}
            \{% if (prop.is_a?(TypeDeclaration) && var[:name].id == prop.var.id) || (prop.is_a?(Assign) && var[:name].id == prop.target.id) %}
              \{% index = i
                opts = var
                opts[:visibility] = nopts[:visibility]
                opts[:converter] = nopts[:converter] %}
            \{% end %}
        \{% end %}
        \{%
          if prop.is_a?(TypeDeclaration)
            opts[:name] = prop.var
            opts[:type] = prop.type
          end
        %}
        \{%
          if prop.is_a?(TypeDeclaration) || (prop.is_a?(Assign) && opts[:type] != nil)
            if block
              opts[:value] = block
            elsif prop.value.is_a?(Nop)
              opts[:value] = nil
            else
              opts[:value] = prop.value
            end
          else
            raise "a type declaration must be specified to declare a `state_var`"
          end
        %}
        \{%
          if opts[:visibility] == nil || opts[:visibility].id.stringify == "public"
            opts[:visibility] = ""
          end
        %}
        \{%
          if index == STATE_VARIABLES.size
            STATE_VARIABLES << opts
          else
            STATE_VARIABLES[index] = opts
          end
        %}
      end

      # The `state_initialize` macro defines an initialization block
      # that is automatically included in all constructor defined in the
      # included type and its subclasses.
      #
      # It can be used to initialize state variables declared using the
      # `state_var` macro.
      #
      # Example :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var x : Int32
      #   state_var y : Int32
      #
      #   state_initialize do
      #     @x = 0
      #     @y = 0
      #   end
      # ```
      #
      macro state_initialize(&block)
        \{% STATE_INITIALIZE << block.body %}
      end

      private macro redefine_constructors
        \{% if @type.methods.any? { |m| m.name.stringify == "initialize" } %}
          \{% for method in @type.methods %}
            \{% if method.name == "initialize" %}
              def \{{ method.name.id }}(
                \{% if method.splat_index.is_a?(NumberLiteral) %}
                  \{% for arg, index in method.args %}
                    \{{ (index == method.splat_index ? "*" + arg.stringify : arg.stringify).id }},
                  \{% end %}
                \{% else %}
                  \{{ method.args.splat }} \{{ (method.double_splat.is_a?(Nop) && method.block_arg.is_a?(Nop) ? "" : ",").id }}
                \{% end %}
                \{{ (method.double_splat.is_a?(Nop) ? "" : "**" + method.double_splat.stringify).id }}
                \{{ (method.block_arg.is_a?(Nop) ? "" : "&" + method.block_arg.stringify).id }}
              )

                \{% for block in STATE_INITIALIZE %}
                  \{{ block }}
                \{% end %}

                \{{ method.body }}
              end
            \{% end %}
          \{% end %}
        \{% elsif @type.superclass.methods.any? { |m| m.name.stringify == "initialize" } %}
          \{% for method in @type.superclass.methods %}
            \{% if method.name == "initialize" %}
              def \{{ method.name.id }}(
                \{% if method.splat_index.is_a?(NumberLiteral) %}
                  \{% for arg, index in method.args %}
                    \{{ (index == method.splat_index ? "*" + arg.stringify : arg.stringify).id }},
                  \{% end %}
                \{% else %}
                  \{{ method.args.splat }} \{{ (method.double_splat.is_a?(Nop) && method.block_arg.is_a?(Nop) ? "" : ",").id }}
                \{% end %}
                \{{ (method.double_splat.is_a?(Nop) ? "" : "**" + method.double_splat.stringify).id }}
                \{{ (method.block_arg.is_a?(Nop) ? "" : "&" + method.block_arg.stringify).id }}
              )
                super

                \{% for block in STATE_INITIALIZE %}
                  \{{ block }}
                \{% end %}
              end
            \{% end %}
          \{% end %}
        \{% else %}
          def initialize
            \{% for block in STATE_INITIALIZE %}
              \{{ block }}
            \{% end %}
          end
        \{% end %}
      end

      macro finished
        \{% for var in STATE_VARIABLES %}
          \{% if var[:value].is_a?(Block) %}
            @\{{ var[:name].id }} : \{{ var[:type] }}?

            \{{ var[:visibility].id }} def \{{ var[:name].id }} : \{{ var[:type] }}
              @\{{ var[:name].id }} ||= (
                \{{ var[:value].body }}
              )
            end
          \{% else %}
            \{% if var[:value] == nil %}
              @\{{ var[:name].id }} : \{{ var[:type] }}
            \{% else %}
              @\{{ var[:name].id }} : \{{ var[:type] }} = \{{ var[:value] }}
            \{% end %}

            \{{ var[:visibility].id }} def \{{ var[:name].id }} : \{{ var[:type] }}
              @\{{ var[:name].id }}
            end
          \{% end %}
        \{% end %}

        \{% if !STATE_INITIALIZE.empty? %}
          redefine_constructors
        \{% end %}

        \{% if !STATE_VARIABLES.empty? %}
          # A struct that wraps the state of a model
          struct \{{ @type.name.id }}::State < Quartz::State
            include Quartz::Transferable

            \{% for var in STATE_VARIABLES %}
              getter \{{var[:name].id}} : \{{var[:type]}}
            \{% end %}

            def initialize(
              \{{ (STATE_VARIABLES.empty? || STATE_VARIABLES.all? { |var| var[:value] == nil } ? "" : "*, ").id }}
              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] != nil %}
                  \{% if var[:value].is_a?(Block) %}
                    \{{ var[:name].id }} : \{{ var[:type] }}? = nil,
                  \{% else %}
                    \{{ var[:name].id }} : \{{ var[:type] }} = \{{ var[:value] }},
                  \{% end %}
                \{% end %}
              \{% end %}
              **args
            )
              \{% for block in STATE_INITIALIZE %}
                \{{ block }}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] != nil %}
                  \{% if var[:value].is_a?(Block) %}
                    if \{{ var[:name].id }}.nil?
                      \{{ var[:name].id }} = (
                        \{{ var[:value].body }}
                      )
                    end
                  \{% end %}
                  @\{{ var[:name].id }} = \{{ var[:name].id }}
                \{% end %}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] == nil %}
                  if value = args[:\{{ var[:name].id }}]?
                    @\{{ var[:name].id }} = value
                  end
                \{% end %}
              \{% end %}
            end

            def initialize(hash : Hash(Symbol, Union(
              \{% for var, index in STATE_VARIABLES %}
                \{{ var[:type] }} \{{ (index == STATE_VARIABLES.size-1 ? ")" : "|").id }}
              \{% end %}
            ))
              \{% for block in STATE_INITIALIZE %}
                \{{ block }}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] != nil %}
                  if !hash.has_key?(:\{{ var[:name].id }})
                    \{% if var[:value].is_a?(Block) %}
                        hash[:\{{ var[:name].id }}] = (
                          \{{ var[:value].body }}
                        )
                    \{% else %}
                      hash[:\{{ var[:name].id }}] = \{{ var[:value] }}
                    \{% end %}
                  end
                  @\{{ var[:name].id }} = hash[:\{{ var[:name].id }}].as(\{{ var[:type] }})
                \{% end %}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] == nil %}
                  if value = hash[:\{{ var[:name].id }}]?
                    @\{{ var[:name].id }} = value.as(\{{ var[:type] }})
                  end
                \{% end %}
              \{% end %}
            end

            def initialize(hash : Hash(String, Union(
              \{% for var, index in STATE_VARIABLES %}
                \{{ var[:type] }} \{{ (index == STATE_VARIABLES.size-1 ? ")" : "|").id }}
              \{% end %}
            ))
              \{% for block in STATE_INITIALIZE %}
                \{{ block }}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] != nil %}
                  if !hash.has_key?(\{{ var[:name].stringify }})
                    \{% if var[:value].is_a?(Block) %}
                        hash[:\{{ var[:name].id }}] = (
                          \{{ var[:value].body }}
                        )
                    \{% else %}
                      hash[\{{ var[:name].stringify }}] = \{{ var[:value] }}
                    \{% end %}
                  end
                  @\{{ var[:name].id }} = hash[\{{ var[:name].stringify }}].as(\{{ var[:type] }})
                \{% end %}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value] == nil %}
                  if value = hash[\{{ var[:name].stringify }}]?
                    @\{{ var[:name].id }} = value.as(\{{ var[:type] }})
                  end
                \{% end %}
              \{% end %}
            end

            def initialize(%pull : ::JSON::PullParser)
              \{% for block in STATE_INITIALIZE %}
                \{{ block }}
              \{% end %}

              \{% for var in STATE_VARIABLES %}
                \%found{var[:name].id} = false
                \%json{var[:name].id} = nil
              \{% end %}

              %pull.read_object do |key|
                case key
                \{% for var in STATE_VARIABLES %}
                  when \{{ var[:name].stringify }}
                    \%found{var[:name].id} = true

                    \%json{var[:name].id} =
                        \{% if var[:json_converter] || var[:converter] %}
                          \{{var[:json_converter] || var[:converter]}}.from_json(%pull)
                        \{% elsif var[:type].is_a?(Path) || var[:type].is_a?(Generic) %}
                          \{{var[:type]}}.new(%pull)
                        \{% else %}
                          ::Union(\{{var[:type]}}).new(%pull)
                        \{% end %}
                \{% end %}
                else
                  raise JSON::ParseException.new("unknown json attribute: #{key}", 0, 0)
                end
              end

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value].is_a?(Block) %}
                  @\{{ var[:name].id }} = if \%found{var[:name].id}
                    \%json{var[:name].id}.as(\{{var[:type]}})
                  else
                    \{{ var[:value].body }}
                  end
                \{% elsif var[:value] == nil %}
                  if \%found{var[:name].id} && (value = \%json{var[:name].id})
                    @\{{var[:name].id}} = value.as(\{{var[:type]}})
                  end
                \{% else %}
                  @\{{var[:name].id}} = \%found{var[:name].id} ? \%json{var[:name].id}.as(\{{var[:type]}}) : \{{var[:value]}}
                \{% end %}
              \{% end %}
            end

            def to_tuple
              Tuple.new(
                \{% for var in STATE_VARIABLES %}
                  \{{ var[:name].id }},
                \{% end %}
              )
            end

            def to_named_tuple
              NamedTuple.new(
                \{% for var in STATE_VARIABLES %}
                  \{{ var[:name].id }}: \{{ var[:name].id }},
                \{% end %}
              )
            end

            def to_hash
              {
                \{% for var in STATE_VARIABLES %}
                  :\{{ var[:name].id }} => \{{ var[:name].id }},
                \{% end %}
              }
            end

            def to_json(json : JSON::Builder)
              json.object do
                \{% for var in STATE_VARIABLES %}
                  json.field(\{{ var[:name].stringify }}) do
                    \{% if var[:converter] %}
                      if value = \{{var[:name].id}}
                        \{{ var[:converter] }}.to_json(value, json)
                      else
                        nil.to_json(json)
                      end
                    \{% else %}
                      \{{var[:name].id}}.to_json(json)
                    \{% end %}
                  end
                \{% end %}
              end
            end


          end

          def initial_state=(state : \{{@type.name.id}}::State)
            @_initial_state = state
          end

          @_initial_state : Quartz::State?

          protected def initial_state
            (@_initial_state || \{{@type.name.id}}::State.new).as(\{{@type.name.id}}::State)
          end

          def state
            \{{ @type.name }}::State.new(
              \{% for var in STATE_VARIABLES %}
                \{{ var[:name].id }}: \{{ var[:name].id }},
              \{% end %}
            )
          end

          def dup_state
            \{{ @type.name }}::State.new(
              \{% for var in STATE_VARIABLES %}
                \{{ var[:name].id }}: \{{ var[:name].id }}.dup,
              \{% end %}
            )
          end

          protected def state=(state : \{{@type.name.id}}::State)
            \{% for var in STATE_VARIABLES %}
              @\{{ var[:name].id }} = state.\{{ var[:name].id }}
            \{% end %}
          end
        \{% else %}
          struct \{{ @type.name }}::State < Quartz::State
          end

          def state
            \{{ @type.name }}::State.new
          end

          def dup_state
            \{{ @type.name }}::State.new
          end

          protected def state=(state : Quartz::State)
          end

          protected def initial_state
          end
        \{% end %}
      end

      macro inherited
        \{% if !@type.has_constant?(:STATE_VARIABLES) %}
          include Quartz::AutoState
          \{% for x in STATE_VARIABLES %}
            \{% if x[:value].is_a?(Block) %}
              state_var(\{{x[:name]}} : \{{x[:type]}}, visibility: \{{x[:visibility] || ""}}) \{{ x[:value] }}
            \{% elsif x[:value] == nil %}
              state_var(\{{x[:name]}} : \{{x[:type]}}, visibility: \{{x[:visibility] || "" }})
            \{% else %}
              state_var(\{{x[:name]}} : \{{x[:type]}} = \{{ x[:value] }}, visibility: \{{x[:visibility] || "" }})
            \{% end %}
          \{% end %}
        \{% end %}
      end
    end
  end
end
