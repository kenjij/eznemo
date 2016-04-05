require 'mysql2/em'


module EzNemo

  # Defines DataStorage class for MySQL
  module StorageAdapter

    # Number of records it queues up before writing
    QUEUE_SIZE = 20

    def initialize
      @results = []
      @probe = EzNemo.config[:probe][:name]
      @opts = EzNemo.config[:datastore][:options]
      @opts[:flags] = Mysql2::Client::MULTI_STATEMENTS
    end

    # Creates and returns new instance of {Mysql2::Client}
    # @return [Mysql2::Client]
    def database
      Mysql2::Client.new(@opts)
    end

    # Creates and returns new instance of {Mysql2::EM::Client}
    # @return [Mysql2::EM::Client]
    def emdatabase
      Mysql2::EM::Client.new(@opts)
    end

    # Returns all active checks
    # @return [Array<Hash, ...>]
    def checks
      q = 'SELECT * FROM checks WHERE state = true'
      database.query(q, {symbolize_keys: true, cast_booleans: true})
    end

    # Stores a result; into queue first
    # @param result [Hash] (see {EzNemo::Monitor#report})
    def store_result(result)
      @results << result
      if @results.count >= QUEUE_SIZE
        write_results
      end
    end

    # Write the results to storage from queue
    # @param sync [Boolean] use EM (async) if false
    # @return [Object] Mysql2 client instance
    def write_results(sync = false)
      return nil if @results.empty?
      sync ? db = database : db = emdatabase
      stmt = ''
      @results.each do |r|
        r[:probe] = @probe
        r[:status_desc] = db.escape(r[:status_desc])
        cols = r.keys.join(',')
        vals = r.values.join("','")
        stmt << "INSERT INTO results (#{cols}) VALUES ('#{vals}');"
      end
      @results.clear
      if sync
        db.query(stmt)
      else
        defer = db.query(stmt)
        defer.callback do
        end
        defer.errback do |r|
          puts r.message
          db.close if db.ping
        end
      end
      db
    end

    # Flush queue to storage
    def flush
      if write_results(true)
        puts "Flushed."
      else
        puts "Nothing to flush."
      end
    end

  end

end
