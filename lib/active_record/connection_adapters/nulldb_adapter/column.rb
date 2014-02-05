class ActiveRecord::ConnectionAdapters::NullDBAdapter
  class Column < ::ActiveRecord::ConnectionAdapters::Column
    private

    def simplified_type(field_type)
      type = super
      type = :integer if type.nil? && sql_type == :primary_key
      type
    end
  end
end
