require 'mysql2/em'


module EzNemo

  module StorageAdapter

    QUEUE_SIZE = 20

    def initialize
      @results = []
      @opts = EzNemo.config[:datastore][:options]
      @opts[:flags] = Mysql2::Client::MULTI_STATEMENTS
    end

    def database
      Mysql2::Client.new(@opts)
    end

    def emdatabase
      Mysql2::EM::Client.new(@opts)
    end

    def checks
      q = 'SELECT * FROM checks WHERE state = true'
      database.query(q, {symbolize_keys: true, cast_booleans: true})
    end

    def store_result(r)
      @results << r
      if @results.count >= QUEUE_SIZE
        write_results
      end
    end

    def write_results(sync = false)
      return nil if @results.empty?
      sync ? db = database : db = emdatabase
      stmt = ''
      @results.each do |r|
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
          puts 'Wrote to DB.'
        end
        defer.errback do |r|
          puts r.message
          db.close if db.ping
        end
      end
      db
    end

    def flush
      if write_results(true)
        puts "Flushed."
      else
        puts "Nothing to flush."
      end
    end

  end

end
