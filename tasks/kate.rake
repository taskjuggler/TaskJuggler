# TASK Kate SYNTAX

require 'taskjuggler/KateSyntax'

desc 'Generate kate-tjp.xml Kate syntax file'
task :kate do
  TaskJuggler::KateSyntax.new.generate('data/kate-tjp.xml')
end
