require "logger"
require "colorize"

module Quartz
  class Loggers
    private LOGGER_COLORS = {
      Logger::Severity::ERROR   => :light_red,
      Logger::Severity::FATAL   => :red,
      Logger::Severity::WARN    => :light_yellow,
      Logger::Severity::INFO    => :light_green,
      Logger::Severity::DEBUG   => :light_blue,
      Logger::Severity::UNKNOWN => :light_gray,
    }

    COLOR_FORMATTER = Logger::Formatter.new do |severity, datetime, progname, message, io|
      color = LOGGER_COLORS[severity]
      io << datetime.to_s("(%T:%L)").colorize(color)
      io << " ❯ ".colorize(:black)
      io << message
    end

    SIMPLE_FORMATTER = Logger::Formatter.new do |severity, datetime, progname, message, io|
      io << datetime.to_s("(%T:%L)")
      io << " ❯ "
      io << message
    end

    def initialize(create_default_logger : Bool)
      if create_default_logger
        add_logger(STDOUT)
      end
    end

    private def loggers : Hash(IO, Logger)
      @loggers ||= Hash(IO, Logger).new
    end

    def any_logger? : Bool
      (@loggers.try &.size || 0) > 0
    end

    def any_debug? : Bool
      any_logger? && loggers.each_value.any? &.debug?
    end

    # Add a new logger
    def add_logger(io : IO, level = Logger::INFO, formatter = COLOR_FORMATTER)
      loggers[io] = Logger.new(io).tap do |logger|
        logger.progname = "quartz"
        logger.level = level
        logger.formatter = formatter
      end
    end

    # Remove logger associated with given *io*.
    def remove_logger(io : IO = STDOUT)
      @loggers.try &.delete(io)
    end

    # Change logger severity level for all *loggers*.
    def level=(level : Logger::Severity)
      @loggers.try &.each_value { |logger| logger.level = level }
    end

    def clear
      @loggers.try &.clear
    end

    # Send a debug *message* to loggers
    def debug(message)
      @loggers.try &.each_value { |logger| logger.debug(message) }
    end

    # Send a info *message* to loggers
    def info(message)
      @loggers.try &.each_value { |logger| logger.info(message) }
    end

    # Send a warning *message* to loggers
    def warn(message)
      @loggers.try &.each_value { |logger| logger.warn(message) }
    end

    # Send an error *message* to loggers
    def error(message)
      @loggers.try &.each_value { |logger| logger.error(message) }
    end

    # Send a fatal *message* to loggers
    def fatal(message)
      @loggers.try &.each_value { |logger| logger.fatal(message) }
    end

    def timing(label, delay = false, display_memory = true, padding_size = 34)
      if any_logger?
        io = IO::Memory.new

        io.print "%-*s" % {padding_size, "#{label}:"} unless delay
        start = Time.monotonic
        value = yield
        elapsed_time = Time.monotonic - start
        io.print "%-*s" % {padding_size, "#{label}:"} if delay
        if display_memory
          heap_size = GC.stats.heap_size
          mb = heap_size / 1024.0 / 1024.0
          io.print " %s (%7.2fMB)" % {elapsed_time, mb}
        else
          io.print " %s" % elapsed_time
        end
        str = io.to_s

        loggers.each_value { |logger| logger.info str }

        value
      else
        yield
      end
    end
  end
end
