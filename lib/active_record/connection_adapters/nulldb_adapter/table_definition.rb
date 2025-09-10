class ActiveRecord::ConnectionAdapters::NullDBAdapter
  class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
    attr_accessor :name
    alias enum string
    alias uuid string
    alias citext text
    alias interval text
    alias geometry text
    alias serial integer
    alias bigserial integer
    alias inet string
    alias jsonb json if method_defined? :json
    alias hstore json

    def unique_constraint(*args, **kwargs, &block); end
    def exclusion_constraint(*args); end

    if ::ActiveRecord::VERSION::MAJOR >= 7 && ::ActiveRecord::VERSION::MINOR >= 1
      # Avoid check for option validity
      def create_column_definition(name, type, options)
        ActiveRecord::ConnectionAdapters::ColumnDefinition.new(name, type, options)
      end
    end
  end
end
