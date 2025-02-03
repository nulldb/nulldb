class ActiveRecord::ConnectionAdapters::NullDBAdapter

  class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
    attr_accessor :name
    alias_method :enum, :string
    alias_method :uuid, :string
    alias_method :citext, :text
    alias_method :interval, :text
    alias_method :geometry, :text
    alias_method :serial, :integer
    alias_method :bigserial, :integer
    alias_method :inet, :string
    alias_method :timestamptz, :string
    alias_method :tstzrange, :string
    alias_method :jsonb, :json if method_defined? :json
    alias_method :hstore, :json

    def unique_constraint(*args, **kwargs, &block); end

    if ::ActiveRecord::VERSION::MAJOR >= 7 && ::ActiveRecord::VERSION::MINOR >= 1
      # Avoid check for option validity
      def create_column_definition(name, type, options)
        ActiveRecord::ConnectionAdapters::ColumnDefinition.new(name, type, options)
      end
    end
  end
end
