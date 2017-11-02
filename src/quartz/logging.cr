require "logger"
require "colorize"

module Quartz
  # :nodoc:
  private LOGGER_COLORS = {
    Logger::Severity::ERROR   => :light_red,
    Logger::Severity::FATAL   => :red,
    Logger::Severity::WARN    => :light_yellow,
    Logger::Severity::INFO    => :light_green,
    Logger::Severity::DEBUG   => :light_blue,
    Logger::Severity::UNKNOWN => :light_gray,
  }

  @@logger : Logger? = Logger.new(STDOUT).tap do |logger|
    logger.progname = "quartz"
    logger.level = Logger::INFO

    logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
      color = LOGGER_COLORS[severity]
      io << datetime.to_s("(%T:%L)").colorize(color)
      io << " ❯ ".colorize(:black)
      io << message
    end
  end

  def self.logger : Logger
    raise Exception.new("There is no logger for Quartz to use.") unless @@logger
    @@logger.not_nil!
  end

  def self.logger? : Logger?
    @@logger
  end

  def self.logger=(logger : Logger?)
    @@logger = logger
  end

  def self.timing(label, delay = false, display_memory = true, padding_size = 34)
    if @@logger
      io = IO::Memory.new

      io.print "%-*s" % {padding_size, "#{label}:"} unless delay
      time = Time.now
      value = yield
      elapsed_time = Time.now - time
      io.print "%-*s" % {padding_size, "#{label}:"} if delay
      if display_memory
        heap_size = GC.stats.heap_size
        mb = heap_size / 1024.0 / 1024.0
        io.print " %s (%7.2fMB)" % {elapsed_time, mb}
      else
        io.print " %s" % elapsed_time
      end
      logger.info io.to_s

      value
    else
      yield
    end
  end

  module Logging
    extend self

    # Send a debug *message* to default logger
    def debug(message)
      Quartz.logger?.try &.debug(message)
    end

    # Send a info *message* to default logger
    def info(message)
      Quartz.logger?.try &.info(message)
    end

    # Send a warning *message* to default logger
    def warn(message)
      Quartz.logger?.try &.warn(message)
    end

    # Send an error *message* to default logger
    def error(message)
      Quartz.logger?.try &.error(message)
    end

    def fatal(message)
      Quartz.logger?.try &.fatal(message)
    end
  end
end
