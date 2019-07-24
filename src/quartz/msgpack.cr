require "msgpack"

module Quartz
  class AtomicModel
    def initialize(pull : ::MessagePack::Unpacker)
      pull.read_hash_size
      pull.consume_hash do
        case key = Bytes.new(pull)
        when "name".to_slice
          super(String.new(pull))
        when "state".to_slice
          self.initial_state = {{ (@type.name + "::State").id }}.new(pull)
          self.state = initial_state
        else
          raise MessagePack::UnpackError.new("unknown msgpack attribute: #{String.new(key)}")
        end
      end
    end

    def to_msgpack(packer : ::MessagePack::Packer)
      packer.write_hash_start(2)
      packer.write("name")
      @name.to_msgpack(packer)
      packer.write("state")
      state.to_msgpack(packer)
    end

    def self.from_msgpack(io : IO)
      self.new(::MessagePack::IOUnpacker.new(io))
    end

    def self.from_msgpack(bytes : Bytes)
      from_msgpack(IO::Memory.new(bytes))
    end
  end

  struct State
    def initialize(pull : MessagePack::PullParser)
    end

    def to_msgpack(packer : ::MessagePack::Packer)
    end

    def self.from_msgpack(io : IO)
      self.new(::MessagePack::IOUnpacker.new(io))
    end

    def self.from_msgpack(bytes : Bytes)
      from_msgpack(IO::Memory.new(bytes))
    end
  end

  module AutoState
    macro included
      macro finished
        \{% if !STATE_VARIABLES.empty? %}
        # A struct that wraps the state of a model
        struct \{{ @type.name.id }}::State < Quartz::State
          def initialize(%pull : ::MessagePack::Unpacker)
            \{% for block in STATE_INITIALIZE %}
              \{{ block }}
            \{% end %}

            \{% for var in STATE_VARIABLES %}
              \%found{var[:name].id} = false
              \%mp{var[:name].id} = nil
            \{% end %}

            %pull.read_hash_size
            %pull.consume_hash do
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
                raise MessagePack::UnpackError.new("unknown msgpack attribute: #{String.new(%key)}")
              end
            end

            \{% for var in STATE_VARIABLES %}
              \{% if var[:value].is_a?(Block) %}
                @\{{ var[:name].id }} = if \%found{var[:name].id}
                  \%mp{var[:name].id}.as(\{{var[:type]}})
                else
                  \{{ var[:value].body }}
                end
              \{% elsif var[:value] == nil %}
                if \%found{var[:name].id} && (value = \%mp{var[:name].id})
                  @\{{var[:name].id}} = value.as(\{{var[:type]}})
                end
              \{% else %}
                @\{{var[:name].id}} = \%found{var[:name].id} ? \%mp{var[:name].id}.as(\{{var[:type]}}) : \{{var[:value]}}
              \{% end %}
            \{% end %}
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
        end
        \{% end %}
      end
    end
  end
end
