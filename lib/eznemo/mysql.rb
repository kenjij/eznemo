require 'mysql2/em'
require 'sequel'
require 'thread'


module EzNemo

  # Sequel connection setup
  Sequel.application_timezone = :local
  Sequel.database_timezone = :utc
  Sequel::Model.db = Sequel.connect({adapter: 'mysql2'}.merge(config[:datastore][:options]))

  # Defines DataStore class for MySQL
  module StorageAdapter

    # Number of records it queues up before writing
    DEFAULT_QUEUE_SIZE = 20

    def initialize
      @results = []
      @queue_size = EzNemo.config[:datastore][:queue_size]
      @queue_size ||= DEFAULT_QUEUE_SIZE
      @opts = EzNemo.config[:datastore][:options]
      @opts[:flags] = Mysql2::Client::MULTI_STATEMENTS
    end

    # Creates and returns new instance of {Mysql2::EM::Client}
    # @return [Mysql2::EM::Client]
    def emdatabase
      Mysql2::EM::Client.new(@opts)
    end

    # Returns all active checks
    # @return [Array<EzNemo::Check, ...>]
    def checks
      checks_with_tags(EzNemo.config[:checks][:tags])
    end

    # Returns all active checks matching all tags
    # @param tags [Array<String, ...>] list of tag text
    # @return [Array<EzNemo::Checks, ...>]
    def checks_with_tags(tags = nil)
      cids = check_ids_with_tags(tags)
      return Check.where(state: true).all if cids.nil?
      Check.where(state: true, id: cids).all
    end

    # @param tags [Array<String, ...>] list of tag text
    # @return [Array] check_id mathing all tags; nil when no tags supplied
    def check_ids_with_tags(tags = nil)
      return nil if tags.nil? || tags.empty?
      candi_ids = []
      tags.each { |t| candi_ids << Tag.where(text: t).map(:check_id) }
      final_ids = candi_ids[0]
      candi_ids.each { |ids| final_ids = final_ids & ids }
      final_ids
    end

    # Stores a result; into queue first
    # @param result [Hash] (see {EzNemo::Monitor#report})
    def store_result(result)
      @results << result
      if @results.count >= @queue_size
        write_results
      end
    end

    # Write the results to storage from queue
    # @param sync [Boolean] use EM (async) if false
    # @return [Object] Mysql2 client instance
    def write_results(sync = false)
      logger = EzNemo.logger
      return nil if @results.empty?
      if sync
        logger.debug 'Writing to DB...'
        Result.db.transaction do
          @results.each { |r| r.save}
        end
        return true
      else
        db = emdatabase
        stmt = ''
        @results.each { |r| stmt << Result.dataset.insert_sql(r) + ';' }
        defer = db.query(stmt)
        defer.callback do
        end
        defer.errback do |r|
          logger.error r.message
          db.close if db.ping
        end
      end
      @results.clear
      db
    end

    # Flush queue to storage
    def flush
      logger = EzNemo.logger
      # Won't run after trap; run in another thread
      thr = Thread.new do
        logger.debug 'Spawned flushing thread.'
        if write_results(true)
          logger.info "Flushed."
        else
          logger.info "Nothing to flush."
        end
      end
      thr.join
    end

  end

end
