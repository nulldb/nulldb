require 'rubygems'

$LOAD_PATH << File.join(File.dirname(__FILE__), *%w[.. vendor ginger lib])
require 'ginger'
require 'active_record'
require 'active_record/version'
$: << File.join(File.dirname(__FILE__), "..", "lib")

if ActiveRecord::VERSION::MAJOR > 2
  require 'rspec' # rspec 2
else
  require 'spec' # rspec 1
end

require 'nulldb_rspec'

class Employee < ActiveRecord::Base
  after_save :on_save_finished

  def on_save_finished
  end
end

class TablelessModel < ActiveRecord::Base
end

module Rails
  def self.root
    'Rails.root'
  end
end

describe "NullDB with no schema pre-loaded" do
  before :each do
    Kernel.stub!(:load)
    ActiveRecord::Migration.stub!(:verbose=)
  end

  it "should load Rails.root/db/schema.rb if no alternate is specified" do
    ActiveRecord::Base.establish_connection :adapter => :nulldb
    Kernel.should_receive(:load).with("Rails.root/db/schema.rb")
    ActiveRecord::Base.connection.columns('schema_info')
  end

  it "should load the specified schema relative to Rails.root" do
    Kernel.should_receive(:load).with("Rails.root/foo/myschema.rb")
    ActiveRecord::Base.establish_connection :adapter => :nulldb,
                                            :schema => "foo/myschema.rb"
    ActiveRecord::Base.connection.columns('schema_info')
  end

  it "should suppress migration output" do
    ActiveRecord::Migration.should_receive(:verbose=).with(false)
    ActiveRecord::Base.establish_connection :adapter => :nulldb,
                                            :schema => "foo/myschema.rb"
    ActiveRecord::Base.connection.columns('schema_info')
  end

  it "should allow creating a table without passing a block" do
    ActiveRecord::Base.establish_connection :adapter => :nulldb
    ActiveRecord::Schema.define do
      create_table(:employees)
    end
  end
end

describe "NullDB" do
  before :all do
    ActiveRecord::Base.establish_connection :adapter => :nulldb
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table(:employees) do |t|
        t.string  :name
        t.date    :hire_date
        t.integer :employee_number
        t.decimal :salary
      end

      create_table(:employees_widgets, :id => false) do |t|
        t.integer :employee_id
        t.integer :widget_id
      end

      add_fk_constraint "foo", "bar", "baz", "buz", "bungle"
      add_pk_constraint "foo", "bar", {}, "baz", "buz"
    end
  end

  before :each do
    @employee =  Employee.new(:name           => "John Smith",
                             :hire_date       => Date.civil(2000, 1, 1),
                             :employee_number => 42,
                             :salary          => 56000.00)
  end

  it "should set the @config instance variable so plugins that assume its there can use it" do
    Employee.connection.instance_variable_get(:@config)[:adapter].should == :nulldb
  end

  it "should enable instantiation of AR objects without a database" do
    @employee.should_not be_nil
    @employee.should be_a_kind_of(ActiveRecord::Base)
  end

  it "should remember columns defined in migrations" do
    should_have_column(Employee, :name, :string)
    should_have_column(Employee, :hire_date, :date)
    should_have_column(Employee, :employee_number, :integer)
    should_have_column(Employee, :salary, :decimal)
  end

  it "should return the appropriate primary key" do
    ActiveRecord::Base.connection.primary_key('employees').should == 'id'
  end

  it "should return a nil primary key on habtm" do
    ActiveRecord::Base.connection.primary_key('employees_widgets').should be_nil
  end

  it "should return an empty array of columns for a table-less model" do
    TablelessModel.columns.should == []
  end

  it "should enable simulated saving of AR objects" do
    lambda { @employee.save! }.should_not raise_error
  end

  it "should enable AR callbacks during simulated save" do
    @employee.should_receive(:on_save_finished)
    @employee.save
  end

  it "should enable simulated deletes of AR objects" do
    lambda { @employee.destroy }.should_not raise_error
  end

  it "should enable simulated creates of AR objects" do
    emp = Employee.create(:name => "Bob Jones")
    emp.name.should == "Bob Jones"
  end

  it "should generate new IDs when inserting unsaved objects" do
    cxn = Employee.connection
    id1 = cxn.insert("some sql", "SomeClass Create", "id", nil, nil)
    id2 = cxn.insert("some sql", "SomeClass Create", "id", nil, nil)
    id2.should == (id1 + 1)
  end

  it "should re-use object ID when inserting saved objects" do
    cxn = Employee.connection
    id1 = cxn.insert("some sql", "SomeClass Create", "id", 23, nil)
    id1.should == 23
  end

  it "should log executed SQL statements" do
    cxn = @employee.connection
    exec_count = cxn.execution_log.size
    @employee.save!
    cxn.execution_log.size.should == (exec_count + 1)
  end

  it "should have the adapter name 'NullDB'" do
    @employee.connection.adapter_name.should == "NullDB"
  end

  it "should support migrations" do
    @employee.connection.supports_migrations?.should be_true
  end

  it "should always have a schema_info table definition" do
    @employee.connection.tables.should include("schema_info")
  end

  it "should return an empty array from #select" do
    @employee.connection.select_all("who cares", "blah").should == []
  end

  it "should provide a way to set log checkpoints" do
    cxn = @employee.connection
    @employee.save!
    cxn.execution_log_since_checkpoint.size.should > 0
    cxn.checkpoint!
    cxn.execution_log_since_checkpoint.size.should == 0
    @employee.salary = @employee.salary + 1
    @employee.save!
    cxn.execution_log_since_checkpoint.size.should == 1
  end

  def should_contain_statement(cxn, entry_point)
    cxn.execution_log_since_checkpoint.should \
      include(ActiveRecord::ConnectionAdapters::NullDBAdapter::Statement.new(entry_point))
  end

  def should_not_contain_statement(cxn, entry_point)
    cxn.execution_log_since_checkpoint.should_not \
      include(ActiveRecord::ConnectionAdapters::NullDBAdapter::Statement.new(entry_point))
  end

  it "should tag logged statements with their entry point" do
    cxn = @employee.connection

    should_not_contain_statement(cxn, :insert)
    @employee.save
    should_contain_statement(cxn, :insert)

    cxn.checkpoint!
    should_not_contain_statement(cxn, :update)
    @employee.salary = @employee.salary + 1
    @employee.save
    should_contain_statement(cxn, :update)

    cxn.checkpoint!
    should_not_contain_statement(cxn, :delete)
    @employee.destroy
    should_contain_statement(cxn, :delete)

    cxn.checkpoint!
    should_not_contain_statement(cxn, :select_all)
    Employee.find(:all)
    should_contain_statement(cxn, :select_all)

    cxn.checkpoint!
    should_not_contain_statement(cxn, :select_value)
    Employee.count_by_sql("frobozz")
    should_contain_statement(cxn, :select_value)
  end

  it "should allow #finish to be called on the result of #execute" do
    @employee.connection.execute("blah").finish
  end

  describe 'have_executed rspec matcher' do
    module NullDB::RSpec::NullifiedDatabase
      # avoid checking RSpec::Rails (undefined) constants
      def self.nullify_contextually?(*args);true;end
    end

    include NullDB::RSpec::NullifiedDatabase

    it 'when an execution was expected, passes if an execution was made' do
      Employee.create
      Employee.connection.should have_executed(:insert)
    end

    it 'when an execution was not expected, passes if an execution was not made' do
      Employee.connection.should_not have_executed(:insert)
    end
  end

  def should_have_column(klass, col_name, col_type)
    col = klass.columns_hash[col_name.to_s]
    col.should_not be_nil
    col.type.should == col_type
  end
end

describe NullDB::RSpec::NullifiedDatabase do
  describe '.globally_nullify_database' do
    it 'nullifies the database' do
      NullDB::RSpec::NullifiedDatabase.should respond_to(:nullify_database)
      NullDB::RSpec::NullifiedDatabase.should_receive(:nullify_database)
      NullDB::RSpec::NullifiedDatabase.globally_nullify_database
    end
  end
end

