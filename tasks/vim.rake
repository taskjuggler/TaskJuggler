# TASK VIM SYNTAX 

require 'taskjuggler/VimSyntax'

desc 'Generate vim.tjp Vim syntax file'
task :vim do
  TaskJuggler::VimSyntax.new.generate('tjp.vim')
end

