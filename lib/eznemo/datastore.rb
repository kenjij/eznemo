module EzNemo

  # @return [Object] data storage object; a shared instance
  def self.datastore
    @datastore ||= DataStore.new
  end

  # Storage for checks and results
  class DataStore

    include EzNemo::StorageAdapter

  end

end
