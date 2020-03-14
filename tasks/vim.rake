# TASK VIM SYNTAX

require 'taskjuggler/VimSyntax'

CLOBBER.include "data/tjp.vim"

desc 'Generate vim.tjp Vim syntax file'
task :vim do
  TaskJuggler::VimSyntax.new.generate('data/tjp.vim')
end

