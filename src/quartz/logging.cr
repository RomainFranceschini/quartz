require "logger"

module Quartz

  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::INFO

  def self.logger : Logger
    @@logger
  end

  def self.logger=(logger : Logger)
    @@logger = logger
  end

  module Logging
    extend self

    # Send a debug *message* to default logger
    def debug(message)
      Quartz.logger.debug(message)
    end

    # Send a info *message* to default logger
    def info(message)
      Quartz.logger.info(message)
    end

    # Send a warning *message* to default logger
    def warn(message)
      Quartz.logger.warn(message)
    end

    # Send an error *message* to default logger
    def error(message)
      Quartz.logger.error(message)
    end
  end
end
