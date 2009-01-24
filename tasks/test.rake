
require 'rake/testtask'

# TEST TASK
test_task_name = HAVE_EXT ? :test_ext : :test
Rake::TestTask.new( test_task_name ) do |t|
    t.libs = REQUIRE_PATHS
    t.test_files = TEST_FILES
    t.verbose = false
end
