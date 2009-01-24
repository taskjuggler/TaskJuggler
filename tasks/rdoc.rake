
require 'rake/rdoctask'

# RDOC
GENERAL_RDOC_OPTS = {
    "--title"   => "#{PROJECT_NAME} API documentation",
    "--main"    => README
}

# RDOC TASK
Rake::RDocTask.new(:rdoc) do |t|
    t.rdoc_files    = RDOC_FILES + LIB_FILES
    t.title         = GENERAL_RDOC_OPTS['--title']
    t.main          = GENERAL_RDOC_OPTS['--main']
    t.rdoc_dir      = RDOC_DIR
    t.options       += [ "--inline-source", "--line-numbers" ]
end
