require "log"
require "colorize"

Log.setup_from_env(
  level: ENV.fetch("CRYSTAL_LOG_LEVEL", "INFO"),
  sources: ENV.fetch("CRYSTAL_LOG_SOURCES", "quartz.*"),
  backend: Log::IOBackend.new.tap do |backend|
    backend.formatter = Quartz::FORMATTER
  end
)

module Quartz
  Log = ::Log.for(self)

  @@colors = true

  def self.colorize_logs=(value : Bool)
    @@colors = value
  end

  private LOGGER_COLORS = {
    ::Log::Severity::Fatal   => :red,
    ::Log::Severity::Error   => :light_red,
    ::Log::Severity::Warning => :light_yellow,
    ::Log::Severity::Info    => :light_green,
    ::Log::Severity::Verbose => :light_gray,
    ::Log::Severity::Debug   => :light_blue,
    ::Log::Severity::None    => :dark_gray,
  }

  FORMATTER = ::Log::Formatter.new do |entry, io|
    message = entry.message
    colorize = @@colors && io.tty? && Colorize.enabled?

    if colorize
      color = LOGGER_COLORS.fetch(entry.severity, :default)
      io << entry.timestamp.to_s("(%T:%L)").colorize(color)
      io << " ❯ ".colorize(:black) << message
    else
      io << entry.severity.label[0] << ": " << entry.timestamp.to_s("(%T:%L)")
      io << " ❯ " << message
    end
  end

  def self.set_no_log_backend
    Log.backend = nil
  end

  def self.set_io_log_backend
    Log.backend = Log::IOBackend.new.tap do |backend|
      backend.formatter = Quartz::FORMATTER
    end
  end

  def self.set_warning_log_level
    Log.level = ::Log::Severity::Warning
  end

  def self.set_debug_log_level
    Log.level = ::Log::Severity::Debug
  end

  def self.timing(label, display_memory = true, padding_size = 34)
    start_time = Time.monotonic
    retval = yield
    Log.info {
      elapsed_time = Time.monotonic - start_time
      io = IO::Memory.new
      io.print "%-*s" % {padding_size, "#{label}:"}
      if display_memory
        heap_size = GC.stats.heap_size
        mb = heap_size / 1024.0 / 1024.0
        io.print " %s (%7.2fMB)" % {elapsed_time, mb}
      else
        io.print " %s" % elapsed_time
      end
      io.to_s
    }
    retval
  end
end
