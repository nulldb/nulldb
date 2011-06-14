require 'ginger'
 
def create_scenario(version)
  scenario = Ginger::Scenario.new("Rails #{version}")
  scenario[/^active_?record$/] = version
  scenario[/^active_?support$/] = version
  scenario
end

Ginger.configure do |config|
  config.aliases["active_record"] = "activerecord"
  config.aliases["active_support"] = "activesupport"

  versions = []

  # Rails 3 only works on Ruby 1.8.7 and 1.9.2
  if %w[1.8.7 1.9.2].include?(RUBY_VERSION)
    if ENV['TEST_RAILS_3_1']
      versions << '3.1.0.rc4'
    else
      versions << '3.0.8'
    end
  end
  versions += %w( 2.3.8 2.3.5 2.3.4 2.3.3 2.3.2 )
  versions += %w(
    2.2.3 2.2.2
    2.1.2 2.1.1 2.1.0
    2.0.5 2.0.4 2.0.2 2.0.1 2.0.0
  ) if RUBY_VERSION =~ /^1\.8/
  versions.each do |version|
    config.scenarios << create_scenario(version)
  end
end
