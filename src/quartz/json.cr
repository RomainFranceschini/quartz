require "json"

module Quartz
  struct Duration
    include JSON::Serializable
  end

  struct Scale
    include JSON::Serializable
  end

  class State
    def to_json(json : ::JSON::Builder)
      json.object do
        {% for ivar in @type.instance_vars %}
          json.field({{ivar.name.stringify}}) { self.{{ivar.name}}.to_json(json) }
        {% end %}
      end
    end

    def initialize(pull : ::JSON::PullParser)
      {% begin %}
        {% for ivar in @type.instance_vars %}
          %found{ivar.name} = false
          %json{ivar.name} = nil
        {% end %}

        pull.read_object do |key|
          case key
          {% for ivar in @type.instance_vars %}
          when {{ ivar.name.stringify }}
              %json{ivar.name} =
                {% if ivar.type.is_a?(Path) || ivar.type.is_a?(Generic) %}
                  {{ivar.type}}.new(pull)
                {% else %}
                  ::Union({{ivar.type}}).new(pull)
                {% end %}
              %found{ivar.name} = true
          {% end %}
          else
            raise JSON::ParseException.new("unknown json attribute: #{key}", 0, 0)
          end
        end

        {% for ivar in @type.instance_vars %}
          if %found{ivar.name}
            @{{ivar.name}} = (%json{ivar.name}).as({{ivar.type}})
          end
        {% end %}
      {% end %}
    end
  end

  class AtomicModel
    macro def_serialization
      def self.new(pull : ::JSON::PullParser)
        name = nil
        state = nil
        initial_state = nil
        elapsed = nil

        pull.read_object do |key|
          case key
          when "name"
            name = String.new(pull)
          when "state"
            state = {{ (@type.constant(:State)).id }}.new(pull)
          when "initial_state"
            initial_state = {{ (@type.constant(:State)).id }}.new(pull)
          when "elapsed"
            elapsed = Duration.new(pull)
          else
            raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
          end
        end

        {{@type}}.new(
          name.as(String),
          state.as({{ (@type.constant(:State)).id }}),
          initial_state.as({{ (@type.constant(:State)).id }})
        ).tap { |model| model.elapsed = elapsed.as(Duration) }
      end

      def to_json(json : ::JSON::Builder)
        json.object do
          json.field("name") { @name.to_json(json) }
          json.field("state") { state.to_json(json) }
          json.field("initial_state") { initial_state.to_json(json) }
          json.field("elapsed") { @elapsed.to_json(json) }
        end
      end
    end
  end

  class DTSS::AtomicModel
    macro def_serialization
      def self.new(pull : ::JSON::PullParser)
        name = nil
        state = nil
        initial_state = nil

        pull.read_object do |key|
          case key
          when "name"
            name = String.new(pull)
          when "state"
            state = {{ (@type.constant(:State)).id }}.new(pull)
          when "initial_state"
            initial_state = {{ (@type.constant(:State)).id }}.new(pull)
          else
            raise ::JSON::ParseException.new("Unknown json attribute: #{key}", 0, 0)
          end
        end

        {{@type}}.new(
          name.as(String),
          state.as({{ (@type.constant(:State)).id }}),
          initial_state.as({{ (@type.constant(:State)).id }})
        )
      end

      def to_json(json : ::JSON::Builder)
        json.object do
          json.field("name") { @name.to_json(json) }
          json.field("state") { state.to_json(json) }
          json.field("initial_state") { initial_state.to_json(json) }
        end
      end
    end
  end
end
