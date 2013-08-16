require 'active_record/connection_adapters/nulldb_adapter'
require 'active_record/connection_adapters/postgresql_adapter'

class ActiveRecord::Base
  # Instantiate a new NullDB connection.  Used by ActiveRecord internally.
  def self.nulldb_postgres_connection(config)
    ActiveRecord::ConnectionAdapters::NullDBPostgresAdapter.new(config)
  end
end

class ActiveRecord::ConnectionAdapters::NullDBPostgresAdapter <
    ActiveRecord::ConnectionAdapters::NullDBAdapter

  class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
    include ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::ColumnMethods
  end

  def self.adapter
    :nulldb_postgres
  end

  def enable_extension(extension_name)
    # NOOP
  end

  private

  def new_table_definition(adapter = nil, table_name = nil, is_temporary = nil, options = {})
    case ::ActiveRecord::VERSION::MAJOR
    when 4
      TableDefinition.new(native_database_types, table_name, is_temporary, options)
    else
      raise "Unsupported ActiveRecord version #{::ActiveRecord::VERSION::STRING}"
    end
  end
end
