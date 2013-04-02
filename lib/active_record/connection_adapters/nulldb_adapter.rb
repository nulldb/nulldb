require 'logger'
require 'stringio'
require 'singleton'
require 'pathname'
require 'active_record/connection_adapters/abstract_adapter'
require 'nulldb/core'

unless respond_to?(:tap)
  class Object
    def tap
      yield self
      self
    end
  end
end

unless respond_to?(:try)
  class Object
    def try(*a, &b)
      if a.empty? && block_given?
        yield self
      else
        __send__(*a, &b)
      end
    end
  end

  class NilClass
    def try(*args); nil; end
  end
end

class ActiveRecord::Base
  # Instantiate a new NullDB connection.  Used by ActiveRecord internally.
  def self.nulldb_connection(config)
    ActiveRecord::ConnectionAdapters::NullDBAdapter.new(config)
  end
end


module ActiveRecord
  # Just make sure you have the latest version of your schema
  class Schema < Migration
    def self.define(info={}, &block)
      instance_eval(&block)
    end
  end
end


class ActiveRecord::ConnectionAdapters::NullDBAdapter <
    ActiveRecord::ConnectionAdapters::AbstractAdapter

  class Column < ::ActiveRecord::ConnectionAdapters::Column
    private

    def simplified_type(field_type)
      type = super
      type = :integer if type.nil? && sql_type == :primary_key
      type
    end
  end

  class Statement
    attr_reader :entry_point, :content

    def initialize(entry_point, content = "")
      @entry_point, @content = entry_point, content
    end

    def ==(other)
      self.entry_point == other.entry_point
    end
  end

  class Checkpoint < Statement
    def initialize
      super(:checkpoint, "")
    end

    def ==(other)
      self.class == other.class
    end
  end

  TableDefinition = ActiveRecord::ConnectionAdapters::TableDefinition

  class IndexDefinition < Struct.new(:table, :name, :unique, :columns, :lengths, :orders)
  end

  class NullObject
    def method_missing(*args, &block)
      nil
    end
  end

  class EmptyResult
    def rows
      []
    end
  end

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
  def initialize(config={})
    @log            = StringIO.new
    @logger         = Logger.new(@log)
    @last_unique_id = 0
    @tables         = {'schema_info' =>  TableDefinition.new(nil)}
    @indexes        = Hash.new { |hash, key| hash[key] = [] }
    @schema_path    = config.fetch(:schema){ "db/schema.rb" }
    @config         = config.merge(:adapter => :nulldb)
    super(nil, @logger)
    @visitor = Arel::Visitors::ToSql.new self if defined?(Arel::Visitors::ToSql)
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
    table_definition = ActiveRecord::ConnectionAdapters::TableDefinition.new(self)
    unless options[:id] == false
      table_definition.primary_key(options[:primary_key] || "id")
    end

    yield table_definition if block_given?

    @tables[table_name] = table_definition
  end

  def add_index(table_name, column_names, options = {})
    index_name, index_type, ignore = add_index_options(table_name, column_names, options)
    @indexes[table_name] << IndexDefinition.new(table_name, index_name, (index_type == 'UNIQUE'), column_names, [], [])
  end

  unless instance_methods.include? :add_index_options
    def add_index_options(table_name, column_name, options = {})
      column_names = Array.wrap(column_name)
      index_name   = index_name(table_name, :column => column_names)

      if Hash === options # legacy support, since this param was a string
        index_type = options[:unique] ? "UNIQUE" : ""
        index_name = options[:name].to_s if options.key?(:name)
      else
        index_type = options
      end

      if index_name.length > index_name_length
        raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' is too long; the limit is #{index_name_length} characters"
      end
      if index_name_exists?(table_name, index_name, false)
        raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' already exists"
      end
      index_columns = quoted_columns_for_index(column_names, options).join(", ")

      [index_name, index_type, index_columns]
    end
  end

  def add_fk_constraint(*args)
    # NOOP
  end

  def add_pk_constraint(*args)
    # NOOP
  end

  # Retrieve the table names defined by the schema
  def tables
    @tables.keys.map(&:to_s)
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
        ActiveRecord::ConnectionAdapters::NullDBAdapter::Column.new(
          col_def.name.to_s,
          col_def.default,
          col_def.type,
          col_def.null
        )
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

  def exec_query(statement, name = 'SQL', binds = [])
    self.execution_log << Statement.new(entry_point, statement)
    EmptyResult.new
  end

  def select_rows(statement, name = nil)
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
      super(statement, name)
    end
  end

  def select_all(statement, name=nil, binds = [])
    with_entry_point(:select_all) do
      x = super(statement, name)
      x.class.send(:define_method, :column_types) { [] }
      x
    end
  end

  def select_one(statement, name=nil, binds = [])
    with_entry_point(:select_one) do
      super(statement, name, binds = [])
    end
  end

  def select_values(statement, name=nil)
    with_entry_point(:select_value) do
      super(statement, name)
    end
  end

  def select_value(statement, name=nil, binds = [])
    with_entry_point(:select_value) do
      super(statement, name, binds = [])
    end
  end

  def primary_key(table_name)
    columns(table_name).detect { |col| col.sql_type == :primary_key }.try(:name)
  end

  protected

  def select(statement, name, binds = [])
    [].tap do
      self.execution_log << Statement.new(entry_point, statement)
    end
  end

  private

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
end
