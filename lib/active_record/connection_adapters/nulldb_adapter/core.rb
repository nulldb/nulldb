class ActiveRecord::ConnectionAdapters::NullDBAdapter < ActiveRecord::ConnectionAdapters::AbstractAdapter

  # A convenience method for integratinginto RSpec.  See README for example of
  # use.
  def self.insinuate_into_spec(config)
    config.before :all do
      ActiveRecord::Base.establish_connection(:adapter => :nulldb)
    end

    config.after :all do
      ActiveRecord::Base.establish_connection(:test)
    end
  end

  # Recognized options:
  #
  # [+:schema+] path to the schema file, relative to Rails.root
  # [+:table_definition_class_name+] table definition class
  # (e.g. ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition for Postgres) or nil.
  def initialize(config={})
    @log            = StringIO.new
    @logger         = Logger.new(@log)
    @last_unique_id = 0
    @tables         = {'schema_info' => new_table_definition(nil)}
    @indexes        = Hash.new { |hash, key| hash[key] = [] }
    @schema_path    = config.fetch(:schema){ "db/schema.rb" }
    @config         = config.merge(:adapter => :nulldb)
    super *initialize_args
    @visitor ||= Arel::Visitors::ToSql.new self if defined?(Arel::Visitors::ToSql)

    if config[:table_definition_class_name]
      ActiveRecord::ConnectionAdapters::NullDBAdapter.send(:remove_const, 'TableDefinition')
      ActiveRecord::ConnectionAdapters::NullDBAdapter.const_set('TableDefinition',
        self.class.const_get(config[:table_definition_class_name]))
    end

    register_types
  end

  # A log of every statement that has been "executed" by this connection adapter
  # instance.
  def execution_log
    (@execution_log ||= [])
  end

  # A log of every statement that has been "executed" since the last time
  # #checkpoint! was called, or since the connection was created.
  def execution_log_since_checkpoint
    checkpoint_index = @execution_log.rindex(Checkpoint.new)
    checkpoint_index = checkpoint_index ? checkpoint_index + 1 : 0
    @execution_log[(checkpoint_index..-1)]
  end

  # Inserts a checkpoint in the log.  See also #execution_log_since_checkpoint.
  def checkpoint!
    self.execution_log << Checkpoint.new
  end

  def adapter_name
    "NullDB"
  end

  def supports_migrations?
    true
  end

  def create_table(table_name, options = {})
    table_definition = new_table_definition(self, table_name, options.delete(:temporary), options)

    unless options[:id] == false
      table_definition.primary_key(options[:primary_key] || "id")
    end

    yield table_definition if block_given?

    @tables[table_name.to_s] = table_definition
  end

  def rename_table(table_name, new_name)
    table_definition = @tables.delete(table_name.to_s)

    table_definition.name = new_name.to_s
    @tables[new_name.to_s] = table_definition
  end

  def add_index(table_name, column_names, **options)
    options[:unique] = false unless options.key?(:unique)
    column_names = Array.wrap(column_names).map(&:to_s)

    index, index_type, ignore = add_index_options(table_name, column_names, **options)

    if index.is_a?(ActiveRecord::ConnectionAdapters::IndexDefinition)
      @indexes[table_name] << index
    else
      # Rails < 6.1
      @indexes[table_name] << IndexDefinition.new(table_name, index, (index_type == 'UNIQUE'), column_names, [], [])
    end
  end

  # Rails 6.1+
  if ActiveRecord::VERSION::MAJOR >= 6 and ActiveRecord::VERSION::MINOR > 0
    def remove_index(table_name, column_name = nil, **options )
      index_name = index_name_for_remove(table_name, column_name, options)
      index = @indexes[table_name].reject! { |index| index.name == index_name }
    end
  else
    def remove_index(table_name,  options = {} )
      index_name = index_name_for_remove(table_name, options)
      index = @indexes[table_name].reject! { |index| index.name == index_name }
    end
  end

  def add_fk_constraint(*args)
    # NOOP
  end

  def add_pk_constraint(*args)
    # NOOP
  end

  def enable_extension(*)
    # NOOP
  end

  # Retrieve the table names defined by the schema
  def tables
    @tables.keys.map(&:to_s)
  end

  def views
    [] # TODO: Implement properly if needed - This is new method in rails
  end

  # Retrieve table columns as defined by the schema
  def columns(table_name, name = nil)
    if @tables.size <= 1
      ActiveRecord::Migration.verbose = false
      schema_path = if Pathname(@schema_path).absolute?
                      @schema_path
                    else
                      File.join(NullDB.configuration.project_root, @schema_path)
                    end
      Kernel.load(schema_path)
    end

    if table = @tables[table_name]
      table.columns.map do |col_def|
        col_args = default_column_arguments(col_def)
        ActiveRecord::ConnectionAdapters::NullDBAdapter::Column.new(*col_args)
      end
    else
      []
    end
  end

  # Retrieve table indexes as defined by the schema
  def indexes(table_name, name = nil)
    @indexes[table_name]
  end

  def execute(statement, name = nil)
    self.execution_log << Statement.new(entry_point, statement)
    NullObject.new
  end

  def exec_query(statement, name = 'SQL', binds = [], options = {})
    self.execution_log << Statement.new(entry_point, statement)
    EmptyResult.new
  end

  def select_rows(statement, name = nil, binds = [])
    [].tap do
      self.execution_log << Statement.new(entry_point, statement)
    end
  end

  def insert(statement, name = nil, primary_key = nil, object_id = nil, sequence_name = nil, binds = [])
    (object_id || next_unique_id).tap do
      with_entry_point(:insert) do
        super(statement, name, primary_key, object_id, sequence_name)
      end
    end
  end
  alias :create :insert

  def update(statement, name=nil, binds = [])
    with_entry_point(:update) do
      super(statement, name)
    end
  end

  def delete(statement, name=nil, binds = [])
    with_entry_point(:delete) do
      super(statement, name).size
    end
  end

  def select_all(statement, name=nil, binds = [], options = {})
    with_entry_point(:select_all) do
      super(statement, name)
    end
  end

  def select_one(statement, name=nil, binds = [])
    with_entry_point(:select_one) do
      super(statement, name)
    end
  end

  def select_value(statement, name=nil, binds = [])
    with_entry_point(:select_value) do
      super(statement, name)
    end
  end

  def select_values(statement, name=nil)
    with_entry_point(:select_values) do
      super(statement, name)
    end
  end

  def primary_key(table_name)
    columns(table_name).detect { |col| col.type == :primary_key }.try(:name)
  end

  def add_column(table_name, column_name, type, **options)
    super

    table_meta = @tables[table_name.to_s]
    return unless table_meta

    table_meta.column column_name, type, **options
  end

  def change_column(table_name, column_name, type, options = {})
    table_meta = @tables[table_name.to_s]
    column = table_meta.columns.find { |column| column.name == column_name.to_s }
    return unless column

    column.type = type
    column.options = options if options
  end

  def rename_column(table_name, column_name, new_column_name)
    table_meta = @tables[table_name.to_s]
    column = table_meta.columns.find { |column| column.name == column_name.to_s }
    return unless column

    column.name = new_column_name
  end

  def change_column_default(table_name, column_name, default_or_changes)
    table_meta = @tables[table_name.to_s]
    column = table_meta.columns.find { |column| column.name == column_name.to_s }

    return unless column

    if default_or_changes.kind_of? Hash
      column.default = default_or_changes[:to]
    else
      column.default = default_or_changes
    end
  end

  protected

  def select(statement, name = nil, binds = [])
    EmptyResult.new.tap do |r|
      r.bind_column_meta(columns_for(name))
      self.execution_log << Statement.new(entry_point, statement)
    end
  end

  private

  def columns_for(table_name)
    table_meta = @tables[table_name]
    return [] unless table_meta
    table_meta.columns
  end

  def next_unique_id
    @last_unique_id += 1
  end

  def with_entry_point(method)
    if entry_point.nil?
      with_thread_local_variable(:entry_point, method) do
        yield
      end
    else
      yield
    end
  end

  def entry_point
    Thread.current[:entry_point]
  end

  def with_thread_local_variable(name, value)
    old_value = Thread.current[name]
    Thread.current[name] = value
    begin
      yield
    ensure
      Thread.current[name] = old_value
    end
  end

  def includes_column?
    false
  end

  def new_table_definition(adapter = nil, table_name = nil, is_temporary = nil, options = {})
    case ::ActiveRecord::VERSION::MAJOR
    when 6
      TableDefinition.new(self, table_name, temporary: is_temporary, options: options.except(:id))
    when 5
      TableDefinition.new(table_name, is_temporary, options.except(:id), nil)
    else
      raise "Unsupported ActiveRecord version #{::ActiveRecord::VERSION::STRING}"
    end
  end

  def default_column_arguments(col_def)
    [
      col_def.name.to_s,
      col_def.default.present? ? col_def.default.to_s : nil,
      sql_type_definition(col_def),
      col_def.null.nil? || col_def.null
    ]
  end

  def sql_type_definition(col_def)
    ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
      type: col_def.type,
      sql_type: col_def.type.to_s,
      limit: col_def.limit
    )
  end

  def initialize_args
    [nil, @logger, @config]
  end

  def register_types
    require 'active_model/type'
    ActiveRecord::Type.register(
      :primary_key,
      ActiveModel::Type::Integer,
      adapter: adapter_name,
      override: true
    )
  end
end
