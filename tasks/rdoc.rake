require 'rake/rdoctask'

# RDOC TASK
Rake::RDocTask.new(:rdoc) do |t|
  t.rdoc_files = %w( README.rdoc COPYING CHANGELOG ) +
                 `git ls-files -- lib`.split("\n")
  t.title = "TaskJuggler API documentation"
  t.main = 'README.rdoc'
  t.rdoc_dir = 'doc'
end
