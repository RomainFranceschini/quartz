require "logger"
require "colorize"

module Quartz

  # :nodoc:
  private LOGGER_COLORS = {
    "ERROR"   => :light_red,
    "FATAL"   => :red,
    "WARN"    => :light_yellow,
    "INFO"    => :light_green,
    "DEBUG"   => :light_blue,
    "UNKNOWN" => :light_gray
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
