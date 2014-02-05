class ActiveRecord::ConnectionAdapters::NullDBAdapter

  class EmptyResult < Array
    attr_writer :columns
    def rows
      []
    end

    def column_types
      columns.map{|col| col.type}
    end

    def columns
      @columns ||= []
    end
  end

end
