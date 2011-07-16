$:.unshift File.join(File.dirname(__FILE__), '..', 'test')

require 'rake/testtask'

# TEST TASK
desc 'Run all unit tests in the test directory'
Rake::TestTask.new(:test) do |t|
  t.libs = [ 'lib' ]
  t.test_files = Dir.glob('test/test_*.rb')
  t.verbose = false
  t.warning = true
end
