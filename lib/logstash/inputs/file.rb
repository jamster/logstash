require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Stream events from files.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline filter.
#
# Files are followed in a manner similar to "tail -0F". File rotation
# is detected and handled by this input.
class LogStash::Inputs::File < LogStash::Inputs::Base
  config_name "file"

  # The path to the file to use as an input.
  # You can use globs here, such as "/var/log/*.log"
  config :path, :validate => :array, :required => true

  # Exclusions (matched against the filename, not full path). Globs
  # are valid here, too. For example, if you have
  #
  #     path => "/var/log/*"
  #
  # you might want to exclude gzipped files:
  #
  #     exclude => "*.gz"
  config :exclude, :validate => :array

  # How often we stat files to see if they have been modified. Increasing
  # this interval will decrease the number of system calls we make, but
  # increase the time to detect new log lines.
  config :stat_interval, :validate => :number, :default => 1

  # How often we expand globs to discover new files to watch.
  config :discover_interval, :validate => :number, :default => 15

  # Where to write the since database (keeps track of the current
  # position of monitored log files).
  config :sincedb_path, :validate => :string,
         :default => "#{ENV['HOME']}/.sincedb"

  # How often to write a since database with the current position of
  # monitored log files.
  config :sincedb_write_interval, :validate => :number, :default => 15

  public
  def register
    require "filewatch/tail"
    LogStash::Util::set_thread_name("input|file|#{path.join(":")}")
    @logger.info("Registering file input for #{path.join(":")}")
  end # def register

  public
  def run(queue)
    config = {
      :exclude => @exclude,
      :stat_interval => @stat_interval,
      :discover_interval => @discover_interval,
      :sincedb_path => @sincedb_path,
      :sincedb_write_interval => @sincedb_write_interval,
      :logger => @logger,
    }
    tail = FileWatch::Tail.new(config)
    tail.logger = @logger
    @path.each { |path| tail.tail(path) }
    hostname = Socket.gethostname

    tail.subscribe do |path, line|
      source = "file://#{hostname}/#{path}"
      @logger.debug({:path => path, :line => line})
      e = to_event(line, source)
      if e
        queue << e
      end
    end
  end # def run
end # class LogStash::Inputs::File
