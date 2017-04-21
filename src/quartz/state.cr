module Quartz

  abstract struct State
  end

  module AutoState

    macro included
      {% if !@type.constant :STATE_VARIABLES %}
        private STATE_VARIABLES = [] of Nil
        private AFTER_INITIALIZE = [] of Nil
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
      # end
      # ```
      #
      # If default values are omitted, a chance is given to initialize those
      # state variables through a constructor or using the `after_initialize`
      # macro :
      #
      # ```
      # class MyModel < AtomicModel
      #   state_var x : Int32 = 0
      #   state_var y : Int32 = 0
      #
      #   def initialize
      #     @x = 0
      #     @y = 0
      #   end
      # end
      # ```
      #
      # `state_var` also accept a hash or named tuple literal whose
      # keys corresponds to the following options :
      # * *visibility*: used to restrict the visibility of the getter that
      # is defined for this state variable (`:private` or `:protected`). No
      # restriction is applied by default (public).
      # * *converter*: specify an alternate type for parsing and generation.
      # The converter must define `from_json(JSON::PullParser)` and
      # `to_json(value, JSON::Builder)` as class methods. Examples of converters
      # are `Time::Format` and `Time::EpochConverter` for `Time`.
      #
      macro state_var(prop, **opts, &block)
        \{%
          opts[:name] = prop.var
          if prop.is_a?(TypeDeclaration)
            opts[:type] = prop.type
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
          if opts[:visibility] == nil
            opts[:visibility] = ""
          end
          STATE_VARIABLES << opts
        %}
      end

      macro after_initialize(&block)
        \{% AFTER_INITIALIZE << block.body %}
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

        \{% if !STATE_VARIABLES.empty? %}

          # A struct that wraps the state of a model
          struct \{{ @type.name.id }}::State < Quartz::State
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
                  if value = args[:\{{ var[:name].id }}]? || args[\{{ var[:name].stringify }}]?
                    @\{{ var[:name].id }} = value
                  end
                \{% end %}
              \{% end %}

              \{% for block in AFTER_INITIALIZE %}
                \{{ block }}
              \{% end %}
            end

            def initialize(hash : Hash(Symbol, Union(
              \{% for var, index in STATE_VARIABLES %}
                \{{ var[:type] }} \{{ (index == STATE_VARIABLES.size-1 ? ")" : "|").id }}
              \{% end %}
            ))
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

              \{% for block in AFTER_INITIALIZE %}
                \{{ block }}
              \{% end %}
            end

            def initialize(hash : Hash(String, Union(
              \{% for var, index in STATE_VARIABLES %}
                \{{ var[:type] }} \{{ (index == STATE_VARIABLES.size-1 ? ")" : "|").id }}
              \{% end %}
            ))
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

              \{% for block in AFTER_INITIALIZE %}
                \{{ block }}
              \{% end %}
            end

            def initialize(%pull : ::JSON::PullParser)
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
                \{% else %}
                  @\{{var[:name].id}} = \%found{var[:name].id} ? \%json{var[:name].id}.as(\{{var[:type]}}) : \{{var[:value]}}
                \{% end %}
              \{% end %}

              \{% for block in AFTER_INITIALIZE %}
                \{{ block }}
              \{% end %}
            end

            def initialize(%pull : ::MessagePack::Unpacker)
              \{% for var in STATE_VARIABLES %}
                \%found{var[:name].id} = false
                \%mp{var[:name].id} = nil
              \{% end %}

              %pull.read_hash(false) do
                case %key = Bytes.new(%pull)
                \{% for var in STATE_VARIABLES %}
                  when \{{ var[:name].stringify }}.to_slice
                    \%found{var[:name].id} = true

                    \%mp{var[:name].id} =
                        \{% if var[:json_converter] || var[:converter] %}
                          \{{var[:json_converter] || var[:converter]}}.from_msgpack(%pull)
                        \{% elsif var[:type].is_a?(Path) || var[:type].is_a?(Generic) %}
                          \{{var[:type]}}.new(%pull)
                        \{% else %}
                          ::Union(\{{var[:type]}}).new(%pull)
                        \{% end %}
                \{% end %}
                else
                  raise MessagePack::UnpackException.new("unknown msgpack attribute: #{String.new(%key)}")
                end
              end

              \{% for var in STATE_VARIABLES %}
                \{% if var[:value].is_a?(Block) %}
                  @\{{ var[:name].id }} = if \%found{var[:name].id}
                    \%mp{var[:name].id}.as(\{{var[:type]}})
                  else
                    \{{ var[:value].body }}
                  end
                \{% else %}
                  @\{{var[:name].id}} = \%found{var[:name].id} ? \%mp{var[:name].id}.as(\{{var[:type]}}) : \{{var[:value]}}
                \{% end %}
              \{% end %}

              \{% for block in AFTER_INITIALIZE %}
                \{{ block }}
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

            def to_msgpack(packer : ::MessagePack::Packer)
              packer.write_hash_start(\{{ STATE_VARIABLES.size }})

              \{% for var in STATE_VARIABLES %}
                packer.write(\{{var[:name].stringify}})
                \{% if var[:converter] %}
                  if value = \{{var[:name].id}}
                    \{{ var[:converter] }}.to_msgpack(value, packer)
                  else
                    nil.to_msgpack(packer)
                  end
                \{% else %}
                  \{{var[:name].id}}.to_msgpack(packer)
                \{% end %}
              \{% end %}
            end

            def self.from_json(io : IO)
              self.new(::JSON::PullParser.new(io))
            end

            def self.from_json(str : String)
              from_json(IO::Memory.new(str))
            end

            def self.from_msgpack(io : IO)
              self.new(::MessagePack::Unpacker.new(io))
            end

            def self.from_msgpack(bytes : Bytes)
              from_msgpack(IO::Memory.new(bytes))
            end
          end

          # Function used
          def initial_state=(state : \{{@type.name.id}}::State)
            @_initial_state = state
          end

          @_initial_state : \{{@type.name.id}}::State?

          protected def initial_state
            @_initial_state
          end

          def state
            \{{ @type.name }}::State.new(
              \{% for var in STATE_VARIABLES %}
                \{{ var[:name].id }}: \{{ var[:name].id }},
              \{% end %}
            )
          end

          protected def state=(state : \{{@type.name.id}}::State)
            \{% for var in STATE_VARIABLES %}
              @\{{ var[:name].id }} = state.\{{ var[:name].id }}
            \{% end %}
          end

        \{% else %}
          def state
            Quartz::State.new
          end

          protected def state=(state : Quartz::State)
          end

          protected def initial_state
            nil
          end
        \{% end %}
      end

      macro inherited
        \{% if !@type.has_constant?(:STATE_VARIABLES) %}
          include Quartz::AutoState
          \{% for x in STATE_VARIABLES %}
            \{% if x[:value].is_a?(Block) %}
              state_var \{{x[:name]}} : \{{x[:type]}}, visibility: \{{x[:visibility] || ""}} \{{ x[:value] }}
            \{% else %}
              state_var \{{x[:name]}} : \{{x[:type]}} = \{{ x[:value] }}, visibility: \{{x[:visibility] || "" }}
            \{% end %}
          \{% end %}
        \{% end %}
      end
    end
  end
end
