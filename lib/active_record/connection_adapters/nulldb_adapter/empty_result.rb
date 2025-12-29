class ActiveRecord::ConnectionAdapters::NullDBAdapter
  class EmptyResult < Array
    def bind_column_meta(columns)
      @columns = columns
      return if columns.empty?

      @column_types = columns.each_with_object({}) do |col, ctypes|
        ctypes[col.name] = ActiveRecord::Type.lookup(col.type)
      end
    end

    def columns
      @columns ||= []
    end

    def column_types
      @column_types ||= {}
    end

    def cast_values(type_overrides = nil)
      rows
    end

    def rows
      []
    end

    def >(other)
      rows.size > other
    end

    def includes_column?(name)
      false
    end
  end
end
