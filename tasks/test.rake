$:.unshift File.join(File.dirname(__FILE__), '..', 'test')

require 'rake/testtask'

CLEAN.include "test/TestSuite/Export-Reports/refs/Leave.tjp"
CLEAN.include "test/TestSuite/Export-Reports/refs/ListAttributes.tjp"
CLEAN.include "test/TestSuite/Export-Reports/refs/Macro-4.tjp"
CLEAN.include "test/TestSuite/Export-Reports/refs/TraceReport.tjp"

# TEST TASK
desc 'Run all unit tests in the test directory'
Rake::TestTask.new(:unittest) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.verbose = false
  t.warning = true
end
