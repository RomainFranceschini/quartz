module Quartz
  class NoSuchChildError < Exception; end
  class BadSynchronisationError < Exception; end
  class NoSuchPortError < Exception; end
  class InvalidPortHostError < Exception; end
  class InvalidPortModeError < Exception; end
  class MessageAlreadySentError < Exception; end
  class FeedbackLoopError < Exception; end
  class UnobservablePortError < Exception; end

  class StrictValidationFailed < Exception; end

  # TODO doc (see ActiveModel)
  class Errors
    include Enumerable(String)

    @messages : Hash(Symbol, Array(String))?

    @[AlwaysInline]
    def messages
      @messages ||= Hash(Symbol, Array(String)).new { |h,k| h[k] = Array(String).new }
    end

    def each
      @messages.try &.each do |attribute, messages|
        messages.each do |message|
          yield attribute, message
        end
      end
    end

    def each
      @messages.try &.each
    end

    def add(attribute : Symbol, message : String, strict : Bool = false)
      raise StrictValidationFailed.new("#{attribute} #{message}") if strict
      messages[attribute] << message
    end

    def add(attribute : Symbol, *errors : String, strict : Bool = false)
      errors.each do |message|
        add(attribute, message, strict)
      end
    end

    def clear
      @messages.try &.clear
    end

    def empty?
      @messages.nil? || @messages.try &.empty?
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
