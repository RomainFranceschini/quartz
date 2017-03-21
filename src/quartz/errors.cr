module Quartz
  class NoSuchChildError < Exception; end

  class BadSynchronisationError < Exception; end

  class NoSuchPortError < Exception; end

  class InvalidPortHostError < Exception; end

  class MessageAlreadySentError < Exception; end

  class FeedbackLoopError < Exception; end

  class UnobservablePortError < Exception; end

  class StrictValidationFailed < Exception
    getter validation_errors : ValidationErrors

    def initialize(@validation_errors)
    end

    def message : String?
      String.build do |str|
        @validation_errors.each do |attribute, message|
          str << '\'' << attribute << "' " << message << '\n'
        end
      end
    end
  end

  class ValidationErrors
    include Enumerable({Symbol, String})

    @messages : Hash(Symbol, Array(String))?

    @[AlwaysInline]
    def messages
      @messages ||= Hash(Symbol, Array(String)).new { |h, k|
        h[k] = Array(String).new
      }
    end

    def full_messages
      map { |attribute, message| "'#{attribute}' #{message}" }
    end

    def each
      @messages.try &.each do |attribute, messages|
        messages.each do |message|
          yield({attribute, message})
        end
      end
    end

    def add(attribute : Symbol, message : String)
      messages[attribute] << message
    end

    def add(attribute : Symbol, *errors : String)
      errors.each do |message|
        add(attribute, message)
      end
    end

    def clear
      @messages.try &.clear
    end

    def empty?
      @messages.nil? || @messages.not_nil!.empty?
    end

    def include?(attribute : Symbol)
      if m = @messages
        m.has_key?(attribute) && !m[attribute].empty?
      else
        false
      end
    end

    def [](attribute)
      @messages.try { |m| m[attribute] if m.has_key?(attribute) }
    end

    def size
      if m = @messages
        m.values.flatten.size
      else
        0
      end
    end
  end
end
