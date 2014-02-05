# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: activerecord-nulldb-adapter 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "activerecord-nulldb-adapter"
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Avdi Grimm", "Myron Marston"]
  s.date = "2014-01-31"
  s.description = "A database backend that translates database interactions into no-ops. Using NullDB enables you to test your model business logic - including after_save hooks - without ever touching a real database."
  s.email = "myron.marston@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.files = [
    ".travis.yml",
    "Appraisals",
    "CHANGES.md",
    "Gemfile",
    "LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "activerecord-nulldb-adapter.gemspec",
    "gemfiles/activerecord_2.3.gemfile",
    "gemfiles/activerecord_3.0.gemfile",
    "gemfiles/activerecord_3.1.gemfile",
    "gemfiles/activerecord_3.2.gemfile",
    "gemfiles/activerecord_4.0.gemfile",
    "lib/active_record/connection_adapters/nulldb_adapter.rb",
    "lib/activerecord-nulldb-adapter.rb",
    "lib/nulldb.rb",
    "lib/nulldb/arel_compiler.rb",
    "lib/nulldb/core.rb",
    "lib/nulldb/rails.rb",
    "lib/nulldb_rspec.rb",
    "lib/tasks/database.rake",
    "spec/nulldb_spec.rb",
    "spec/spec.opts"
  ]
  s.homepage = "http://github.com/nulldb/nulldb"
  s.licenses = ["MIT"]
  s.rubyforge_project = "nulldb"
  s.rubygems_version = "2.2.0"
  s.summary = "The Null Object pattern as applied to ActiveRecord database adapters"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, [">= 2.0.0"])
      s.add_runtime_dependency(%q<iconv>, [">= 0"])
      s.add_development_dependency(%q<spec>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 1.2.9"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, [">= 0"])
      s.add_development_dependency(%q<appraisal>, [">= 0"])
    else
      s.add_dependency(%q<activerecord>, [">= 2.0.0"])
      s.add_dependency(%q<iconv>, [">= 0"])
      s.add_dependency(%q<spec>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 1.2.9"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
      s.add_dependency(%q<appraisal>, [">= 0"])
    end
  else
    s.add_dependency(%q<activerecord>, [">= 2.0.0"])
    s.add_dependency(%q<iconv>, [">= 0"])
    s.add_dependency(%q<spec>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 1.2.9"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
    s.add_dependency(%q<appraisal>, [">= 0"])
  end
end

