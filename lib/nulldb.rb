module NullDB
  def self.nullify(options={})
    @prev_connection = ActiveRecord::Base.connection_pool.try(:spec)
    ActiveRecord::Base.establish_connection(options.merge(:adapter => :nulldb))
  end
  
  def self.restore
    if @prev_connection
      ActiveRecord::Base.establish_connection(@prev_connection)
    end
  end

  def self.checkpoint
    ActiveRecord::Base.connection.checkpoint!
  end
end

