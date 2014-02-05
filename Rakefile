require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'activerecord-nulldb-adapter'
    gem.summary = %Q{The Null Object pattern as applied to ActiveRecord database adapters}
    gem.description = %Q{A database backend that translates database interactions into no-ops. Using NullDB enables you to test your model business logic - including after_save hooks - without ever touching a real database.}
    gem.email = "myron.marston@gmail.com"
    gem.homepage = "http://github.com/nulldb/nulldb"
    gem.authors = ["Avdi Grimm", "Myron Marston"]
    gem.rubyforge_project = "nulldb"
    gem.license = "MIT"

    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
end

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "LICENSE", "lib/**/*.rb")
end

desc "Publish project home page"
task :publish => ["rdoc"] do
  sh "scp -r html/* myronmarston@rubyforge.org:/var/www/gforge-projects/nulldb"
end
