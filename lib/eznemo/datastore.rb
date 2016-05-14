module EzNemo

  # @return [Object] data storage object; a shared instance
  def self.datastore
    @datastore ||= DataStore.new
  end

  # Sequel models
  class Check < Sequel::Model
    one_to_many :tags
  end

  class Tag < Sequel::Model
    many_to_one :check
  end

  class Result < Sequel::Model
    many_to_one :check
  end

  # Storage for checks and results
  class DataStore

    include EzNemo::StorageAdapter

  end

end
