require 'rake'
require 'rspec/core/rake_task'

desc 'Run all RSpec tests in the spec directory'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = SPEC_PATTERN
end
