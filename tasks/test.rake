$:.unshift File.join(File.dirname(__FILE__), '..', 'test')

require 'rake/testtask'

# TEST TASK
desc 'Run all unit tests in the test directory'
Rake::TestTask.new(:unittest) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.verbose = false
  t.warning = true
end
