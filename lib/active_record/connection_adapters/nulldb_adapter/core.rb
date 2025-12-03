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

  def create_schema(*args)
    # NOOP
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
  if ActiveRecord.version >= Gem::Version.new('6.1.a')
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
    internal_exec_query(statement, name, binds, **options)
  end

  def internal_exec_query(statement, name = 'SQL', binds = [], prepare: false, async: false)
    self.execution_log << Statement.new(entry_point, statement)
    EmptyResult.new
  end

  def select_rows(statement, name = nil, binds = [], async: false)
    [].tap do
      self.execution_log << Statement.new(entry_point, statement)
    end
  end

  def insert(statement, name = nil, primary_key = nil, object_id = nil, sequence_name = nil, binds = [], returning: nil)
    with_entry_point(:insert) do
      super(statement, name, primary_key, object_id, sequence_name)
    end

    result = object_id || next_unique_id

    returning ? [result] : result
  end
  alias :create :insert

  def update(statement, name=nil, binds = [])
    with_entry_point(:update) do
      super(statement, name)
    end
  end

  def delete(statement, name=nil, binds = [])
    with_entry_point(:delete) do
      super(statement, name)
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

  ### Rails 8.0+ ###
  # Rails 8.2+ uses QueryIntent object, earlier versions use individual arguments
  # https://github.com/rails/rails/pull/55897
  if defined?(ActiveRecord::ConnectionAdapters::QueryIntent)
    def perform_query(raw_connection, intent)
      self.execution_log << Statement.new(entry_point, intent.processed_sql)
      ActiveRecord::Result.empty
    end

    def cast_result(raw_result)
      # NullDB returns ActiveRecord::Result directly, no casting needed
      raw_result
    end
  else
    def perform_query(raw_connection, statement, binds, type_casted_binds, prepare:, notification_payload:, batch:)
      self.execution_log << Statement.new(entry_point, statement)
      NullObject.new
    end
  end

  def affected_rows(raw_result)
    0
  end

  def valid_column_definition_options
    super + [:array, :using, :cast_as, :as, :type, :enum_type, :stored, :srid]
  end

  READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
    :close, :declare, :fetch, :move, :set, :show
  ) # :nodoc:
  private_constant :READ_QUERY

  def write_query?(sql) # :nodoc:
    !READ_QUERY.match?(sql)
  rescue ArgumentError # Invalid encoding
    !READ_QUERY.match?(sql.b)
  end

  def reconnect
    true
  end
  ### Rails 8.0+ ###

  protected

  def select(statement, name = nil, binds = [], prepare: nil, async: nil, allow_retry: nil)
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
    when 6, 7, 8
      TableDefinition.new(self, table_name, temporary: is_temporary, options: options.except(:id))
    when 5
      TableDefinition.new(table_name, is_temporary, options.except(:id), nil)
    else
      raise "Unsupported ActiveRecord version #{::ActiveRecord::VERSION::STRING}"
    end
  end

  def native_database_types
    {}
  end

  def default_column_arguments(col_def)
    # ActiveRecord 8.1+ expects: name, cast_type, default, sql_type_metadata, null
    # Earlier versions expect: name, default, sql_type_metadata, null
    if ::ActiveRecord.version >= Gem::Version.new('8.1.a')
      cast_type = ActiveRecord::ConnectionAdapters::AbstractAdapter::TYPE_MAP.lookup(col_def.type.to_s)
      sql_type_meta = sql_type_definition(col_def)

      [
        col_def.name.to_s,
        cast_type,
        col_def.default.present? ? col_def.default.to_s : nil,
        sql_type_meta,
        col_def.null.nil? || col_def.null
      ]
    else
      sql_type_meta = sql_type_definition(col_def)

      [
        col_def.name.to_s,
        col_def.default.present? ? col_def.default.to_s : nil,
        sql_type_meta,
        col_def.null.nil? || col_def.null
      ]
    end
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

  # Register types only once to avoid ActiveRecord::TypeConflictError
  # in ActiveRecord::Type::Registration#<=>
  REGISTRATION_MUTEX = Mutex.new

  def register_types
    REGISTRATION_MUTEX.synchronize do
      return if self.class.types_registered

      self.class.types_registered = true
    end

    ActiveRecord::Type.register(
      :primary_key,
      ActiveModel::Type::Integer,
      adapter: adapter_name,
      override: true
    )

    ActiveRecord::Type.add_modifier({ array: true }, DummyOID, adapter: :nulldb)
    ActiveRecord::Type.add_modifier({ range: true }, DummyOID, adapter: :nulldb)
  end

  class << self
    attr_accessor :types_registered
  end

  class DummyOID < ActiveModel::Type::Value
    attr_reader :subtype

    def initialize(*args)
      @subtype = args.first
    end
  end
end
