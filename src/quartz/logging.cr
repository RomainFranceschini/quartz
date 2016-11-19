require "logger"

module Quartz
  @@logger : Logger? = Logger.new(STDOUT)
  @@logger.not_nil!.level = Logger::INFO

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
