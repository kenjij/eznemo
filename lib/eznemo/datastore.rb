module EzNemo

  def self.datastore
    @datastore ||= DataStore.new
  end

  class DataStore

    include EzNemo::StorageAdapter

    # def checks
    # end

  end

end
