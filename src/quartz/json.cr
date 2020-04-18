require "json"

module Quartz
  struct Duration
    include JSON::Serializable
  end

  struct Scale
    include JSON::Serializable
  end

  class State
    macro inherited
      {% puts "state inherited to #{@type}" %}
      macro finished
        \{% puts "carry on init for #{@type}" %}
        def initialize(pull : ::JSON::PullParser)
          \{% for block in STATE_INITIALIZE %}
            \{{block}}
          \{% end %}
          super
        end
      end
    end

    def initialize(pull : ::JSON::PullParser)
      {% begin %}
        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
            {%
              properties[ivar.id] = {
                type:        ivar.type,
                key:         ivar.id.stringify,
                has_default: ivar.has_default_value?,
                default:     ivar.default_value,
                nilable:     ivar.type.nilable?,
              }
            %}
        {% end %}

        {% for name, value in properties %}
          %var{name} = nil
          %found{name} = false
        {% end %}

        %location = pull.location
        begin
          pull.read_begin_object
        rescue exc : ::JSON::ParseException
          raise ::JSON::MappingError.new(exc.message, self.class.to_s, nil, *%location, exc)
        end
        until pull.kind.end_object?
          %key_location = pull.location
          key = pull.read_object_key
          case key
          {% for name, value in properties %}
            when {{value[:key]}}
              %found{name} = true
              begin
                %var{name} =
                  {% if value[:nilable] || value[:has_default] %} pull.read_null_or { {% end %}
                  ::Union({{value[:type]}}).new(pull)
                {% if value[:nilable] || value[:has_default] %} } {% end %}
              rescue exc : ::JSON::ParseException
                raise ::JSON::MappingError.new(exc.message, self.class.to_s, {{value[:key]}}, *%key_location, exc)
              end
          {% end %}
          else
            pull.skip
          end
        end
        pull.read_next

        {% for name, value in properties %}
          {% unless value[:nilable] || value[:has_default] %}
            if %var{name}.nil? && !%found{name} && !::Union({{value[:type]}}).nilable?
              raise ::JSON::MappingError.new("Missing JSON attribute: {{value[:key].id}}", self.class.to_s, nil, *%location, nil)
            end
          {% end %}

          {% if value[:nilable] %}
            {% if value[:has_default] != nil %}
              @{{name}} = %found{name} ? %var{name} : {{value[:default]}}
            {% else %}
              @{{name}} = %var{name}
            {% end %}
          {% elsif value[:has_default] %}
            @{{name}} = %var{name}.nil? ? {{value[:default]}} : %var{name}
          {% else %}
            @{{name}} = (%var{name}).as({{value[:type]}})
          {% end %}
        {% end %}
      {% end %}
    end

    def to_json(json : ::JSON::Builder)
      {% begin %}
        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {%
            properties[ivar.id] = {
              type: ivar.type,
              key:  ivar.id.stringify,
            }
          %}
        {% end %}

        json.object do
          {% for name, value in properties %}
            _{{name}} = @{{name}}
            json.field({{value[:key]}}) do
              _{{name}}.to_json(json)
            end
          {% end %}
        end
      {% end %}
    end
  end

  class AtomicModel
    def initialize(pull : ::JSON::PullParser)
      pull.read_object do |key|
        case key
        when "name"
          super(String.new(pull))
        when "state"
          self.state = State.new(pull)
        when "elapsed"
          @elapsed = Duration.new(pull)
        else
          raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
        end
      end
    end

    def to_json(json : ::JSON::Builder)
      json.object do
        json.field("name") { @name.to_json(json) }
        json.field("state") { state.to_json(json) }
        json.field("elapsed") { @elapsed.to_json(json) }
      end
    end

    def self.from_json(io : IO)
      self.new(::JSON::PullParser.new(io))
    end

    def self.from_json(str : String)
      from_json(IO::Memory.new(str))
    end
  end

  class DTSS
    :AtomicModel

    def initialize(pull : ::JSON::PullParser)
      @elapsed = Duration.new(0, model_precision)

      pull.read_object do |key|
        case key
        when "name"
          super(String.new(pull))
        when "state"
          self.initial_state = {{ (@type.name + "::State").id }}.new(pull)
          self.state = initial_state
        else
          raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
        end
      end
    end

    def to_json(json : ::JSON::Builder)
      json.object do
        json.field("name") { @name.to_json(json) }
        json.field("state") { state.to_json(json) }
      end
    end

    def self.from_json(io : IO)
      self.new(::JSON::PullParser.new(io))
    end

    def self.from_json(str : String)
      from_json(IO::Memory.new(str))
    end
  end
end
